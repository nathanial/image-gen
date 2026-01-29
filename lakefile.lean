import Lake
open Lake DSL System

package «image-gen» where
  version := v!"0.1.0"

require crucible from "../../testing/crucible"
require oracle from "../../network/oracle"
require parlance from "../../util/parlance"

-- Curl link args (required by oracle via wisp)
def curlLinkArgs : Array String :=
  if Platform.isOSX then
    #["-L/opt/homebrew/lib", "-L/usr/local/lib", "-L/opt/homebrew/anaconda3/lib",
      "-lcurl", "-Wl,-rpath,/opt/homebrew/lib", "-Wl,-rpath,/opt/homebrew/anaconda3/lib",
      "-Wl,-rpath,/usr/local/lib"]
  else if Platform.isWindows then #["-lcurl"]
  else #["-lcurl", "-Wl,-rpath,/usr/lib", "-Wl,-rpath,/usr/local/lib"]

@[default_target]
lean_lib ImageGen where
  roots := #[`ImageGen]

lean_exe «image-gen» where
  root := `ImageGen.Main
  moreLinkArgs := curlLinkArgs

lean_lib Tests where
  roots := #[`Tests]

@[test_driver]
lean_exe «image-gen_tests» where
  root := `Tests.Main
  moreLinkArgs := curlLinkArgs
