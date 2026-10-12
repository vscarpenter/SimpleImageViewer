# StillView 5.1 screenshot photo credits

Reviewed October 12, 2026. This set reuses the existing demo photographs from `../screenshots-4.3.0/sample-photos/`. It does not introduce newly downloaded photographs.

The [official Picsum documentation](https://picsum.photos/) identifies Unsplash as its image source and documents the `/id/{id}/info` endpoint and EXIF User Comment ID. For each JPEG below, the embedded Picsum ID matches the mapping in `../screenshots-4.3.0/scripts/prep_photos.swift`. The author and source link come from that ID's official metadata endpoint, fetched during this review.

| Local filename | Photographer | Picsum metadata | Source page |
| --- | --- | --- | --- |
| `fjord-overlook.jpg` | Alexey Topolyanskiy | [1015](https://picsum.photos/id/1015/info) | [Unsplash](https://unsplash.com/photos/-oWyJoSqBRM) |
| `canyon-sunset.jpg` | Philippe Wuyts | [1016](https://picsum.photos/id/1016/info) | [Unsplash](https://unsplash.com/photos/_h7aBovKia4) |
| `highland-road.jpg` | Andrew Ridley | [1018](https://picsum.photos/id/1018/info) | [Unsplash](https://unsplash.com/photos/Kt5hRENuotI) |
| `storm-coast.jpg` | Patrick Fore | [1019](https://picsum.photos/id/1019/info) | [Unsplash](https://unsplash.com/photos/V6s1cmE39XM) |
| `northern-lights.jpg` | Vashishtha Jogi | [1022](https://picsum.photos/id/1022/info) | [Unsplash](https://unsplash.com/photos/bClr95glx6k) |
| `city-from-above.jpg` | freddie marriage | [1029](https://picsum.photos/id/1029/info) | [Unsplash](https://unsplash.com/photos/utwYoEu9SU8) |
| `winter-camp.jpg` | Wolfgang Lutz | [1036](https://picsum.photos/id/1036/info) | [Unsplash](https://unsplash.com/photos/yOujaSETXlo) |
| `forest-waterfall.jpg` | Andrew Coelho | [1039](https://picsum.photos/id/1039/info) | [Unsplash](https://unsplash.com/photos/VB-w_3dnyvI) |
| `hilltop-castle.jpg` | Rachel Davis | [1040](https://picsum.photos/id/1040/info) | [Unsplash](https://unsplash.com/photos/tn2rBnvIl9I) |
| `valley-river.jpg` | Christian Joudrey | [1043](https://picsum.photos/id/1043/info) | [Unsplash](https://unsplash.com/photos/mWRR1xj95hg) |
| `brick-alley.jpg` | sergee bee | [1047](https://picsum.photos/id/1047/info) | [Unsplash](https://unsplash.com/photos/bIQiMWxX_WU) |
| `lakeside-dock.jpg` | Ales Krivec | [1051](https://picsum.photos/id/1051/info) | [Unsplash](https://unsplash.com/photos/HkTMcmlMOUQ) |
| `sea-foam.jpg` | Anna Popović | [1053](https://picsum.photos/id/1053/info) | [Unsplash](https://unsplash.com/photos/x7HJdJZqplo) |
| `raspberries.jpg` | Glen Carrie | [429](https://picsum.photos/id/429/info) | [Unsplash](https://unsplash.com/photos/FjjUVn_KHLU) |

The [Unsplash license](https://unsplash.com/license), reviewed on the same date, permits free commercial and non-commercial use. Attribution is appreciated. Its exclusions include selling images without significant modification and compiling images to replicate a similar or competing service. These credits preserve the source information for the screenshot artwork.

## Verification scope

`asset-provenance.json` records each unchanged local file's SHA-256, embedded EXIF User Comment, preparation-script mapping, and complete metadata response. Only JSON metadata was retrieved; no source photographs were downloaded or compared pixel by pixel. The matching script and embedded IDs support the source association, but do not constitute an independently verified pixel-level match to the legacy JPEGs.

The preparation script deliberately injected camera, exposure, dates, GPS where present, and keyword metadata for the Info inspector demonstration. Those values are synthetic demo data and should not be described as verified facts about the original photographs or their capture locations. Asset filenames are local demo labels.

## Text-recognition fixture

`sample-documents/trailhead-notice.png` is an authored StillView screenshot-kit document depicting a fictional Fjord Overlook Trail notice. It is not a photograph of a real sign and is not sourced from Unsplash. Its local hash and dimensions are recorded in the provenance manifest. The screenshot can show the app's real on-device OCR of this fixture.
