package examples.scalajs

final class Greeting:
  def message(name: String): String = s"Hello, $name!"

object Greetings:
  def message(name: String): String = new Greeting().message(name)
