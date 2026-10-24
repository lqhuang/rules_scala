package examples.native

object GreetingsTest:
  def main(args: Array[String]): Unit =
    assert(Greetings.message("Bazel") == "Hello, Bazel!")
    assert(!args.contains("--fail"), "intentional failure")
