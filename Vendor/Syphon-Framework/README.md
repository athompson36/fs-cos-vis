Syphon is an open source Mac OS X technology that allows applications to share video and still images with one another in realtime. 

See http://syphon.github.io for more information.

This project hosts the Syphon.framework for developers who want to integrate Syphon in their own software. If you are looking for the Syphon plugins for Quartz Composer, Max/Jitter, FFGL, etc, the project for the Syphon Implementations currently at http://github.com/Syphon

## FS-COS-VIS vendor tweaks

The Xcode project here is adjusted so Swift can `import Syphon` and angle-bracket headers like `#import <Syphon/SyphonImageBase.h>` resolve correctly:

- **Product** is **`Syphon.framework`** (was `Syphonix.framework`; legacy `productName` was `OpenVideoTap`).
- Re-apply these `Syphon.xcodeproj` edits if you replace this folder from upstream.
