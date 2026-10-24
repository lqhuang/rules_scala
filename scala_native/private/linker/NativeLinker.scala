package scala.scalanative.bazel

import java.nio.file.{Files, Path, Paths, StandardCopyOption}
import java.util.concurrent.ConcurrentLinkedQueue

import scala.util.{Failure, Success, Try}

import scala.scalanative.build.{Build, Config, IO, Logger, NativeConfig}
import scala.scalanative.util.Scope

object NativeLinker {
  private val joinedPathOptionPrefixes = Seq(
    "--gcc-toolchain=",
    "--sysroot=",
    "-resource-dir=",
    "-iframework",
    "-isystem",
    "-isysroot",
    "-iquote",
    "-include",
    "-I",
    "-L",
    "-F",
    "-B",
    "@"
  )
  private val separatePathOptions = Set(
    "-iframework",
    "-isystem",
    "-isysroot",
    "-iquote",
    "-include",
    "-I",
    "-L",
    "-F",
    "-B"
  )

  private val logMessages = new ConcurrentLinkedQueue[String]()
  private val logger = Logger(
    traceFn = error => logMessages.add(error.toString),
    debugFn = _ => (),
    infoFn = _ => (),
    warnFn = logMessages.add,
    errorFn = logMessages.add
  )

  final case class Options(
      mainClass: String,
      classpath: Seq[Path],
      output: Path,
      workDir: Path,
      clang: Path,
      clangPP: Path,
      compileOptions: Seq[String],
      cOptions: Seq[String],
      cppOptions: Seq[String],
      linkingOptions: Seq[String]
  )

  def main(args: Array[String]): Unit = {
    val exitCode = Try(parseArgs(args)).map(link) match {
      case Success(_) => 0
      case Failure(error) =>
        logMessages.forEach(message => System.err.println(message))
        System.err.println(s"Scala Native linking failed: ${error.getMessage}")
        error.printStackTrace(System.err)
        1
    }
    System.exit(exitCode)
  }

  private def parseArgs(args: Array[String]): Options = {
    var mainClass: String = null
    var classpath = Seq.empty[Path]
    var output: Path = null
    var workDir: Path = null
    var clang: Path = null
    var clangPP: Path = null
    var compileOptions = Seq.empty[String]
    var cOptions = Seq.empty[String]
    var cppOptions = Seq.empty[String]
    var linkingOptions = Seq.empty[String]

    def value(index: Int, flag: String): String = {
      if (index + 1 >= args.length)
        throw new IllegalArgumentException(s"Missing value for $flag")
      args(index + 1)
    }

    var index = 0
    while (index < args.length) {
      val flag = args(index)
      flag match {
        case "--main" =>
          mainClass = value(index, flag)
        case "--classpath" =>
          classpath :+= Paths.get(value(index, flag))
        case "--output" =>
          output = Paths.get(value(index, flag))
        case "--work-dir" =>
          workDir = Paths.get(value(index, flag))
        case "--clang" =>
          clang = Paths.get(value(index, flag))
        case "--clang++" =>
          clangPP = Paths.get(value(index, flag))
        case "--compile-option" =>
          compileOptions :+= value(index, flag)
        case "--c-option" =>
          cOptions :+= value(index, flag)
        case "--cpp-option" =>
          cppOptions :+= value(index, flag)
        case "--linking-option" =>
          linkingOptions :+= value(index, flag)
        case unknown =>
          throw new IllegalArgumentException(s"Unknown argument: $unknown")
      }
      index += 2
    }

    val missing = Seq(
      "--main" -> mainClass,
      "--output" -> output,
      "--work-dir" -> workDir,
      "--clang" -> clang,
      "--clang++" -> clangPP
    ).collect { case (flag, null) => flag }
    if (missing.nonEmpty)
      throw new IllegalArgumentException(
        s"Missing required arguments: ${missing.mkString(", ")}"
      )

    Options(
      mainClass = mainClass,
      classpath = classpath,
      output = output,
      workDir = workDir,
      clang = clang,
      clangPP = clangPP,
      compileOptions = compileOptions,
      cOptions = cOptions,
      cppOptions = cppOptions,
      linkingOptions = linkingOptions
    )
  }

  private def link(options: Options): Path = {
    val execRoot = Paths.get("").toAbsolutePath.normalize
    val compileOptions =
      resolveToolchainPaths(execRoot, options.compileOptions)
    val cOptions =
      resolveToolchainPaths(execRoot, options.cOptions)
    val cppOptions =
      resolveToolchainPaths(execRoot, options.cppOptions)
    val linkingOptions =
      resolveToolchainPaths(execRoot, options.linkingOptions)

    IO.deleteRecursive(options.workDir)
    try {
      val nativeConfig = NativeConfig.empty
        .withClang(resolvePath(execRoot, options.clang))
        .withClangPP(resolvePath(execRoot, options.clangPP))
        .withCompileOptions(compileOptions)
        .withCOptions(cOptions)
        .withCppOptions(cppOptions)
        .withLinkingOptions(linkingOptions)
        .withBaseName("app")

      val config = Config.empty
        .withBaseDir(options.workDir)
        .withModuleName("app")
        .withMainClass(Some(options.mainClass))
        .withClassPath(options.classpath)
        .withCompilerConfig(nativeConfig)
        .withLogger(logger)

      val artifact = Scope { implicit scope =>
        Build.buildCachedAwait(config)
      }
      val outputParent = options.output.getParent
      if (outputParent != null)
        Files.createDirectories(outputParent)
      Files.move(
        artifact,
        options.output,
        StandardCopyOption.REPLACE_EXISTING
      )
    } finally {
      IO.deleteRecursive(options.workDir)
    }
  }

  private def resolveToolchainPaths(
      execRoot: Path,
      options: Seq[String]
  ): Seq[String] = {
    var pathFollows = false
    options.map { option =>
      if (pathFollows) {
        pathFollows = false
        resolvePath(execRoot, Paths.get(option)).toString
      } else if (separatePathOptions.contains(option)) {
        pathFollows = true
        option
      } else {
        joinedPathOptionPrefixes
          .collectFirst {
            case prefix
                if option.startsWith(prefix) &&
                  option.length > prefix.length &&
                  option.charAt(prefix.length) != '-' =>
              prefix + resolvePath(
                execRoot,
                Paths.get(option.substring(prefix.length))
              )
          }
          .getOrElse {
            if (
              option.startsWith("bazel-out/") ||
              option.startsWith("external/")
            )
              resolvePath(execRoot, Paths.get(option)).toString
            else option
          }
      }
    }
  }

  private def resolvePath(execRoot: Path, path: Path): Path =
    if (path.isAbsolute) path else execRoot.resolve(path).normalize
}
