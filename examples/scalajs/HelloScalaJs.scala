package examples.scalajs

import scala.scalajs.js

object Main:
  def main(args: Array[String]): Unit =
    val argv = js.Dynamic.global.process.argv.asInstanceOf[js.Array[String]]
    val name = if argv.length > 2 then argv(2) else "Scala.js"
    println(Greetings.message(name))
