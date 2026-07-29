package scala.scalajs.bazel

import java.nio.file.{Files, Path, Paths, StandardCopyOption}
import java.util.Comparator

import scala.concurrent.Await
import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.duration.Duration

import org.scalajs.linker.{
  PathIRContainer,
  PathOutputDirectory,
  StandardImpl
}
import org.scalajs.linker.interface.{ModuleInitializer, StandardConfig}
import org.scalajs.logging.ScalaConsoleLogger

object ScalaJsLinker {
  final case class Options(
      mainClass: String,
      classpath: Seq[Path],
      output: Path,
      workDir: Path
  )

  def main(args: Array[String]): Unit =
    link(parseArgs(args))

  private def parseArgs(args: Array[String]): Options = {
    val pairs = args.grouped(2).map {
      case Array(flag, value) => flag -> value
      case missing =>
        throw new IllegalArgumentException(
          s"Missing value for ${missing.head}"
        )
    }.toList
    val allowed = Set("--main", "--classpath", "--output", "--work-dir")
    pairs.find(pair => !allowed.contains(pair._1)).foreach { pair =>
      throw new IllegalArgumentException(s"Unknown argument: ${pair._1}")
    }

    def required(flag: String): String =
      pairs.collectFirst { case (`flag`, value) => value }.getOrElse {
        throw new IllegalArgumentException(s"Missing required argument: $flag")
      }

    Options(
      mainClass = required("--main"),
      classpath = pairs.collect {
        case ("--classpath", value) => Paths.get(value)
      },
      output = Paths.get(required("--output")),
      workDir = Paths.get(required("--work-dir"))
    )
  }

  private def link(options: Options): Unit = {
    delete(options.workDir)
    Files.createDirectories(options.workDir)

    try {
      val cache = StandardImpl.irFileCache().newCache
      val linker = StandardImpl.linker(
        StandardConfig()
          .withSourceMap(false)
          .withBatchMode(true)
      )
      val initializers = List(
        ModuleInitializer.mainMethodWithArgs(options.mainClass, "main")
      )
      val result = PathIRContainer
        .fromClasspath(options.classpath)
        .map(_._1)
        .flatMap(cache.cached)
        .flatMap(
          linker.link(
            _,
            initializers,
            PathOutputDirectory(options.workDir),
            new ScalaConsoleLogger()
          )
        )

      Await.result(result, Duration.Inf)
      val outputParent = options.output.getParent
      if (outputParent != null)
        Files.createDirectories(outputParent)
      Files.move(
        options.workDir.resolve("main.js"),
        options.output,
        StandardCopyOption.REPLACE_EXISTING
      )
    } finally {
      delete(options.workDir)
    }
  }

  private def delete(path: Path): Unit = {
    if (Files.exists(path)) {
      val paths = Files.walk(path)
      try {
        paths
          .sorted(Comparator.reverseOrder())
          .forEach(Files.delete(_))
      } finally {
        paths.close()
      }
    }
  }
}
