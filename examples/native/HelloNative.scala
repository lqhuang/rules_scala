package examples.native

object Main:
  def main(args: Array[String]): Unit =
    val name = args.headOption.getOrElse("Scala Native")
    println(Greetings.message(name))
