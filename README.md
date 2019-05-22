# EmporterKit

An embeddable static library for [Emporter](https://emporter.app).

## Install

1. Add `EmporterKit.xcodeproj` to your Xcode project or workspace
2. Add a dependency to your target (Build Phases > Target Dependencies) to `libEmporterKit.a`
3. Link `libEmporterKit.a` to your target (Build Phases > Link Binary With Libraries)
4. Add `EmporterKit` to your header search paths (Build Settings > Header Search Paths)
5. `#import "Emporter.h"` and make something awesome!

It's recommended to add this repo as a submodule to your project so you can easily keep up to date with any future changes to the API.

## Documentation

The main header [Emporter.h](https://github.com/youngdynasty/EmporterKit/blob/master/EmporterKit/Emporter.h) integrates with Xcode's Quick Help. After importing `EmporterKit` into your project, you should be able navigate through the documentation whenever using referencing the `Emporter` namespace.

## License

BSD 3 Clause. See [LICENSE](https://github.com/youngdynasty/EmporterKit/blob/master/LICENSE).

---

(c) 2019 [Young Dynasty](https://youngdynasty.net)
