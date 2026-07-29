package examples.scalajs

import scala.scalajs.js

object GreetingsTest:
  def main(args: Array[String]): Unit =
    val argv = js.Dynamic.global.process.argv.asInstanceOf[js.Array[String]]
    assert(Greetings.message("Bazel") == "Hello, Bazel!")
    assert(argv.indexOf("--fail") < 0, "intentional failure")
