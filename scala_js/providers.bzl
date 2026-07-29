"""Providers for Scala.js rules."""

ScalaJsInfo = provider(
    doc = "Scala.js IR produced by a library and its transitive dependencies.",
    fields = {
        "ir_jar": "The library jar containing Scala.js IR.",
        "transitive_ir_jars": "All transitive jars containing Scala.js IR.",
    },
)
