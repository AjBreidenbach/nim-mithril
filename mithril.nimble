# Package
import os

version       = "0.1.0"
author        = "Andrew Breidenbach"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"


# Dependencies
switch "outdir", "dist"

task buildJs, "":
  setCommand("js", getPkgDir() / "test" / "index.nim")


task buildJsRelease, "":
  switch "define", "release"
  buildJsTask()

task buildPug, "":
  exec "nimble buildJs"
  exec "pug test/index.pug"


task buildPugRelease, "":
  exec "nimble buildJsRelease"
  exec "terser -m toplevel,reserved=['m'] -c toplevel dist/mithril.js dist/index.js -o dist/bundle.js"
  exec "pug test/release.pug"

requires "nim >= 1.4.8"


