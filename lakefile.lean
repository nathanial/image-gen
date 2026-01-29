import Lake
open Lake DSL

package image-gen where
  version := v!"0.1.0"

require crucible from git "https://github.com/nathanial/crucible" @ "v0.0.9"

@[default_target]
lean_lib UimageUgen where
  roots := #[`UimageUgen]

lean_exe image-gen where
  root := `UimageUgen.Main

lean_lib Tests where
  roots := #[`Tests]

@[test_driver]
lean_exe image-gen_tests where
  root := `Tests.Main
