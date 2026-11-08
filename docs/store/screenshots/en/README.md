# App Store pictures (English)

For App Store Connect, language English (en-US): the pictures in `iphone/` belong to the size “iPhone 6.3" Display”
(1206×2622), those in `ipad/` to “iPad 13" Display” (2064×2752); `manifest.json` names pixel size and files per size.
The pictures in `watch/` belong to the Apple Watch size (416×496), those in `mac/` to “Mac” 16:10 (1280×800).
Upload in the order of the file names (01 first), without captions and without frames.

Made with `LOOSEENDS_UI_LANG=en ./scripts/sim.sh store-screenshots` (#842), never by hand.
Watch pictures with `LOOSEENDS_UI_LANG=en ./scripts/sim.sh store-watch`; Mac pictures only in CI, with the workflow
`store-mac.yml` and `language=en`.
