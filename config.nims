# Adds src/ to the module search path so submodules can use
# `import doggy/site` regardless of where nim is invoked from.
switch("path", thisDir() & "/src")
