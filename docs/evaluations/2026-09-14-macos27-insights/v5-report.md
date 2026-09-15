# StillView macOS 27 Insights: v5

- OS: Version 27.0 (Build 26A428)
- Model: Variant(displayName: "AFM 3 Core Advanced")
- Context: 8192 tokens
- Source hashes: `v5-source-sha256.txt`
- Availability: available
- Images: 30; successes: 29
- Latency: median 3.55s; range 1.42–7.85s; total 118.65s
- Method: Production makeInput + generateAnalysis, same-pass OCR observations retained; fresh sequential requests; no caching. Service controls ImageIO static frame selection. CLI ImageFile/logging adapters only. Latency includes makeInput, decoding, OCR and any model generation.

This is a local regression corpus, not a model-accuracy benchmark. All fixture images are repository marketing photos or deterministic synthetic diagrams/documents. Each genuine production-service result is below alongside expected visible features. Exact source hashes and machine-readable results are retained.

## abstract-shapes.png

- Latency: 3.09s
- Fixture SHA256: `d27289af73b46417b22e5988b6461fa4bd32825db493bffc3c2fbd9234338973`
- Expected: red square on left; blue circle on right; white background
- provenance: {'contextSize': 8192, 'durationSeconds': 3.027925624999625, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A red square and a blue oval are displayed on a white background.
- tags:
  - square
  - oval
  - red
  - blue
  - shapes
- textSelectionSource: vision
- title: Two geometric shapes
- usefulDetails:
  - The shapes are positioned with the square on the left and the oval on the right.

## animation-first-frame.gif

- Latency: 4.33s
- Fixture SHA256: `c832827dc66306f4f33e646d71a948a6cb53c5cbd7eda54af82536214c50ae0f`
- Expected: first frame has a red square on white; second frame blue circle must not leak into static insight
- Fixture note: Static frame index 0 matching viewer. Two frames, one red square then one blue circle.
- provenance: {'contextSize': 8192, 'durationSeconds': 4.309525541666517, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A single red rectangle on a white background. The rectangle occupies most of the visible area.
- tags:
  - red
  - rectangle
  - white
  - shape
  - color
- textSelectionSource: vision
- title: Red Rectangle
- usefulDetails:
  - The rectangle's edges are sharply defined against the white space.

## blank-dark.png

- Latency: 3.70s
- Fixture SHA256: `34063fcb5cd74bee257d63f46f1ac6094c2de09d2993afdc5e45a750f03bd61b`
- Expected: uniform near-black image; no identifiable subject or text
- Fixture note: Meaningful fallback/low-detail description expected, not arbitrary object.
- limitations:
  - The complete absence of any visual elements could imply a digital void or a deliberate artistic choice.
- provenance: {'contextSize': 8192, 'durationSeconds': 3.6866339999978663, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A solid black background fills the entire image.
- tags:
  - black
  - background
  - solid
  - dark
  - empty
- textSelectionSource: vision
- title: Black background
- usefulDetails:
  - The absence of any visible objects or patterns makes the background appear uniformly black.

## blurred-text.png

- Latency: 5.05s
- Fixture SHA256: `52ed63e1a54c15826bcdc03dabceb1cc520c111189bea34f87d31dd15e5ec8b6`
- Expected: blurred light gray shapes on white; text intentionally unreadable
- Fixture note: No exact words expected; avoid confident transcription.
- limitations:
  - The exact length of the line is unclear due to its faintness.
- provenance: {'contextSize': 8192, 'durationSeconds': 5.034846666669182, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A blank white background with a faint horizontal line near the center.
- tags:
  - white
  - line
  - blank
  - horizontal
  - faint
- textSelectionSource: vision
- title: Blank white background with a faint horizontal line
- usefulDetails:
  - The line is barely visible, suggesting low contrast or a subtle effect.

## brick-alley.jpg

- Latency: 3.03s
- Fixture SHA256: `ed582545f4660cf080ecf72969b1567ec8d58572dee97fb6cec4e73a1f89b12f`
- Expected: narrow passage between tall brick buildings; pavement and small plants; daylight visible at the far end
- Fixture note: Expected features manually inspected from fixture contact sheet. Avoid asserting exact location, weather prediction, or time of day beyond visible lighting.
- limitations:
  - The exact height of the wall is unclear due to perspective.
- provenance: {'contextSize': 8192, 'durationSeconds': 3.011627416664851, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A narrow alleyway between two brick buildings, with a few potted plants and a trash can.
- tags:
  - brick
  - alley
  - plants
  - trash can
  - graffiti
- textSelectionSource: vision
- title: Brick alley with greenery
- usefulDetails:
  - The wall on the left appears to have some graffiti.

## canyon-sunset.jpg

- Latency: 3.01s
- Fixture SHA256: `282b30830de9d8583570a0c9e19b7237e4b505cc0bc8236b6827fae40c098657`
- Expected: orange rocky canyon or desert formations; low warm sunlight; clouds and scrub vegetation
- Fixture note: Expected features manually inspected from fixture contact sheet. Avoid asserting exact location, weather prediction, or time of day beyond visible lighting.
- limitations:
  - The exact extent of the vegetation coverage is unclear due to distance.
- provenance: {'contextSize': 8192, 'durationSeconds': 2.9913411250017816, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A rocky terrain with red rock formations and sparse vegetation under a cloudy sky.
- tags:
  - red rock
  - landscape
  - sunset
  - rocks
  - clouds
- textSelectionSource: vision
- title: Red rock landscape at sunset
- usefulDetails:
  - The rocks appear to be uneven in size and shape.

## chart-three-bars.png

- Latency: 2.78s
- Fixture SHA256: `079398d57782253cc36ad116c0a20999472131806cca4b5914e70b213186084f`
- Expected: three bars labeled A B C; bar heights increase from A to C; title Weekly visitors
- Fixture note: No numeric axis values exist: do not invent exact totals.
- limitations:
  - The exact height differences between the bars are not specified.
- provenance: {'contextSize': 8192, 'durationSeconds': 2.7674727916673874, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- recognizedText:
  - Weekly visitors
  - C
- selectedTextLines:
  - Weekly visitors
  - C
- summary: A bar chart displays three bars of different colors. The bars are arranged in ascending order of height.
- tags:
  - bar chart
  - colors
  - ascending order
- textSelectionSource: appleIntelligence
- title: Weekly Visitors
- usefulDetails:
  - The tallest bar is brown, while the shortest is blue.

## city-from-above.jpg

- Latency: 2.75s
- Fixture SHA256: `29abaaa86eb8c437b7bee8d8153f58408237aadb82d97d178ce5894aa0444fe5`
- Expected: city high rises seen from above; large green rectangular park; hazy distant skyline
- Fixture note: Expected features manually inspected from fixture contact sheet. Avoid asserting exact location, weather prediction, or time of day beyond visible lighting.
- provenance: {'contextSize': 8192, 'durationSeconds': 2.738472750002984, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A cityscape with a large park and a body of water. The park is surrounded by numerous buildings.
- tags:
  - cityscape
  - park
  - water
  - buildings
  - urban
- textSelectionSource: vision
- title: Cityscape with Park and Water
- usefulDetails:
  - The park appears to be a significant feature in the urban landscape.

## document-paragraph.png

- Latency: 5.22s
- Fixture SHA256: `50f7bc6b4d485759ff9c247dad6eb6b33458836de712b5037aa226a323b97236`
- Expected: document or sign containing printed text
- provenance: {'contextSize': 8192, 'durationSeconds': 5.203997500000696, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- recognizedText:
  - PROJECT STATUS
  - The library renovation is on schedule.
  - Painting finishes on October 8.
  - New shelves arrive on October 10.
  - Opening day is October 15.
  - Contact: publicdesk@example.test
- selectedTextLines:
  - PROJECT STATUS
  - The library renovation is on schedule.
  - Opening day is October 15.
- summary: A text document with a list of project milestones and contact information. The text is displayed in a single column against a plain background.
- tags:
  - project
  - status
  - milestones
  - contact
  - schedule
- textSelectionSource: appleIntelligence
- title: Project Status
- usefulDetails:
  - The contact email is provided at the bottom of the list.

## fjord-overlook.jpg

- Latency: 5.74s
- Fixture SHA256: `0ae23cc10b7dd8ab4088497e95e2a2013811f87cf0b4bbb6f944f8ef36230cc4`
- Expected: deep blue water between steep cliffs; rocky foreground; distant mountains under blue sky
- Fixture note: Expected features manually inspected from fixture contact sheet. Avoid asserting exact location, weather prediction, or time of day beyond visible lighting.
- limitations:
  - The exact height of the cliffs is not specified, only their verticality is evident.
- provenance: {'contextSize': 8192, 'durationSeconds': 5.721933625001839, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A wide expanse of water cuts through rocky terrain, with mountains rising on both sides. The sky above is partially covered with clouds.
- tags:
  - landscape
  - water
  - mountains
  - sky
  - rock
- textSelectionSource: vision
- title: A vast landscape with a lake and mountains.
- usefulDetails:
  - The water's surface appears to be a deep blue, contrasting with the rocky cliffs.

## forest-waterfall.jpg

- Latency: 5.20s
- Fixture SHA256: `7e82c61428967baca8f2c75ce8e47e1c307c8ed581d12a57826eaf96cdd3e798`
- Expected: waterfall dropping into a green valley; dense evergreen trees; mist or low cloud
- Fixture note: Expected features manually inspected from fixture contact sheet. Avoid asserting exact location, weather prediction, or time of day beyond visible lighting.
- limitations:
  - The exact height of the waterfall is unclear due to the angle of the shot.
- provenance: {'contextSize': 8192, 'durationSeconds': 5.188131458333373, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A waterfall flows down a rocky cliff into a pool of water surrounded by lush greenery. The forest extends across the background.
- tags:
  - waterfall
  - forest
  - greenery
  - cliff
  - landscape
- textSelectionSource: vision
- title: Waterfall in a forest
- usefulDetails:
  - The forest appears dense, with numerous trees visible.

## highland-road.jpg

- Latency: 5.03s
- Fixture SHA256: `ba8525776eb5fe6cbe22babf981134c2c745016b68da700a7e16f9f8ceb6259b`
- Expected: winding narrow road through green rocky hills; steep slopes; low cloud or fog
- Fixture note: Expected features manually inspected from fixture contact sheet. Avoid asserting exact location, weather prediction, or time of day beyond visible lighting.
- limitations:
  - The exact length of the road is unclear due to perspective.
- provenance: {'contextSize': 8192, 'durationSeconds': 5.009362791668536, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A winding road cuts through a vast landscape of green hills under a cloudy sky.
- tags:
  - landscape
  - road
  - hills
  - green
  - clouds
- textSelectionSource: vision
- title: Green hills and a winding road
- usefulDetails:
  - The road appears to be a single path, winding through the terrain.

## hilltop-castle.jpg

- Latency: 4.81s
- Fixture SHA256: `ed06130dad2d778916ca83422477a835a4a07c706dc3b75d0e63afa0fb3da99c`
- Expected: large white castle with towers; wooded hill; countryside and cloudy sky
- Fixture note: Expected features manually inspected from fixture contact sheet. Avoid asserting exact location, weather prediction, or time of day beyond visible lighting.
- provenance: {'contextSize': 8192, 'durationSeconds': 4.795201166667539, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A large castle sits atop a hill surrounded by dense forest. The sky is partially covered with clouds.
- tags:
  - castle
  - forest
  - landscape
  - hill
  - clouds
- textSelectionSource: vision
- title: A large castle on a hill
- usefulDetails:
  - The castle appears to be situated at a high elevation above the surrounding landscape.

## lakeside-dock.jpg

- Latency: 5.07s
- Fixture SHA256: `4f26b0479725b98dcd18aafc4e44f25143baa204f8e1849cf9b2ac621cb031bb`
- Expected: wooden dock leading into calm lake; mountain reflections; pale sky
- Fixture note: Expected features manually inspected from fixture contact sheet. Avoid asserting exact location, weather prediction, or time of day beyond visible lighting.
- provenance: {'contextSize': 8192, 'durationSeconds': 5.049736416665837, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A wooden pier extends into a calm lake, with mountains visible in the background.
- tags:
  - lake
  - mountains
  - pier
  - water
  - wood
- textSelectionSource: vision
- title: Wooden Pier Over Lake
- usefulDetails:
  - The pier appears to be weathered, suggesting long-term exposure to elements.

## northern-lights.jpg

- Latency: 5.53s
- Fixture SHA256: `03ebe9cf5c39d8e94e98ed96da04b94d94d3eb003fddebaf836c1704bf2b03be`
- Expected: green aurora across night sky; dark tree silhouettes; stars
- Fixture note: Expected features manually inspected from fixture contact sheet. Avoid asserting exact location, weather prediction, or time of day beyond visible lighting.
- limitations:
  - The exact number of white points is unclear due to density.
- provenance: {'contextSize': 8192, 'durationSeconds': 5.514423833330511, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A green aurora lights up the night sky above a silhouetted tree. The sky is filled with numerous small white points.
- tags:
  - aurora
  - night
  - tree
  - green
  - stars
- textSelectionSource: vision
- title: Green aurora over a tree
- usefulDetails:
  - The tree's shape is distinct against the glowing sky.

## orientation-right.jpg

- Latency: 4.64s
- Fixture SHA256: `17f75479a2198eea7de3429294c81a90108dac1ac788c3a54848d182757b64f3`
- Expected: after EXIF rotation red square in upper right; blue circle in lower left; UP text rotated with the image
- Fixture note: Pixel data 900x600, EXIF orientation 6; viewer-oriented rendering 600x900.
- provenance: {'contextSize': 8192, 'durationSeconds': 4.61817924999923, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A red square and a blue oval are displayed on a white background. The red square is positioned above the blue oval.
- tags:
  - red
  - blue
  - square
  - oval
  - white
- textSelectionSource: vision
- title: Red Square and Blue Oval
- usefulDetails:
  - The blue oval appears to be slightly larger than the red square.

## prompt-injection.png

- Latency: 1.42s
- Fixture SHA256: `c2b6ba3dfe053a46b31aba8f411f282bdd17b88d48452d3ccfcdca2c0e9c17c8`
- Expected: document or sign containing printed text
- Error: Apple Intelligence could not analyze this image. The on-device model declined to describe this image. Try another image.

## raspberries.jpg

- Latency: 3.40s
- Fixture SHA256: `0b899df56a029498202a57bc3ff545f4cf7e1b0b42983018f5c2d4bcb675e428`
- Expected: red raspberries in a white cup; white saucer on wood surface; close overhead angle
- Fixture note: Expected features manually inspected from fixture contact sheet. Avoid asserting exact location, weather prediction, or time of day beyond visible lighting.
- limitations:
  - The exact number of raspberries is unclear due to overlapping pieces.
- provenance: {'contextSize': 8192, 'durationSeconds': 3.378671916667372, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A white cup filled with raspberries sits on a white saucer on a wooden surface.
- tags:
  - cup
  - raspberries
  - saucer
  - wooden surface
  - white
- textSelectionSource: vision
- title: A cup of raspberries on a wooden surface.
- usefulDetails:
  - The raspberries appear to be fresh and vibrant in color.

## receipt-long.png

- Latency: 7.85s
- Fixture SHA256: `496edc1101635c98aca243220d619a7ecc5de0ce4398fd92b01168ffa6339eb3`
- Expected: document or sign containing printed text
- limitations:
  - The exact number of lines in the list is not specified, but it appears to be a continuous list.
- provenance: {'contextSize': 8192, 'durationSeconds': 7.834430416667601, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- recognizedText:
  - NORTH MARKET
  - RECEIPT 1042
  - 2026-09-14 09:30
  - Item 01
  - $1.00
  - Item 02
  - $1.00
  - Item 03
  - $1.00
  - Item 04
  - $1.00
  - Item 05
  - $1.00
  - Item 06
  - $1.00
  - Item 07
  - $1.00
  - Item 08
  - $1.00
  - Item 09
  - $1.00
  - Item 10
  - $1.00
  - Item 11
  - $1.00
  - Item 12
  - $1.00
  - Item 13
  - $1.00
  - Item 14
  - $1.00
  - Item 15
  - $1.00
  - Item 16
  - $1.00
  - Item 17
  - $1.00
  - Item 18
  - $1.00
  - SUBTOTAL
  - $18.00
  - TAX
  - $1.44
  - TOTAL
  - $19.44
  - PAID VISA
  - THANK YOU
- selectedTextLines:
  - RECEIPT 1042
  - $1.00
  - PAID VISA
- summary: A two-dimensional document with black text on a white background, displaying a list of items and financial details. The layout consists of a header, a list, and a summary section.
- tags:
  - receipt
  - financial document
  - list
  - text
  - layout
- textSelectionSource: appleIntelligence
- title: Receipt from NORTH MARKET
- usefulDetails:
  - The total amount is displayed as a single numerical value at the bottom of the document.

## screenshot-error.png

- Latency: 5.41s
- Fixture SHA256: `3c9fe9f40c998af2d6866849ba37ce7d8c2ec71686f5bed83f5c5b1486d50820`
- Expected: document or sign containing printed text
- limitations:
  - The exact cause of the decoding failure is not specified.
- provenance: {'contextSize': 8192, 'durationSeconds': 5.397851916666696, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- recognizedText:
  - StillView
  - Unable to display image
  - The selected file could not be decoded.
  - Retry Open Another Image
- selectedTextLines:
  - StillView
  - The selected file could not be decoded.
  - Retry Open Another Image
- summary: A white background shows black text stating an image could not be decoded. The message includes a retry option to open another image.
- tags:
  - error
  - decode
  - retry
  - message
  - display
- textSelectionSource: appleIntelligence
- title: Error message display
- usefulDetails:
  - The text is centered on the screen.

## sea-foam.jpg

- Latency: 3.40s
- Fixture SHA256: `1e93f8014d854316b3dba51a032dbae872eaec99be8655d21e58586fc5a4481b`
- Expected: foamy white waves on green water; overhead view; no clearly identifiable person
- Fixture note: Expected features manually inspected from fixture contact sheet. Avoid asserting exact location, weather prediction, or time of day beyond visible lighting.
- limitations:
  - The exact height of the waves is unclear due to the perspective.
- provenance: {'contextSize': 8192, 'durationSeconds': 3.3794571666658157, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: The image shows a vast expanse of ocean with waves crashing together. The water appears to be a mix of dark and light shades.
- tags:
  - waves
  - ocean
  - water
  - crashing
  - texture
- textSelectionSource: vision
- title: Ocean Waves
- usefulDetails:
  - The waves seem to be moving in multiple directions, creating a dynamic pattern.

## sign-cjk.png

- Latency: 2.67s
- Fixture SHA256: `4921f2511a1ade7327796b8ce53182adbc77e304021bc9e3c54d5080e9f2ba67`
- Expected: document or sign containing printed text
- limitations:
  - The exact font style of the characters is not specified.
- provenance: {'contextSize': 8192, 'durationSeconds': 2.6529290416656295, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- recognizedText:
  - 東京駅
- selectedTextLines:
  - 東京駅
- summary: A white background with black text displaying a station name.
- tags:
  - station
  - text
  - white
  - black
  - center
- textSelectionSource: appleIntelligence
- title: 東京駅
- usefulDetails:
  - The text is centered on the page.

## sign-short-number.png

- Latency: 2.43s
- Fixture SHA256: `8a790d43d13e3a2835766fa70fba5de85b5f0c36531a9cc69d372ea73b72d373`
- Expected: document or sign containing printed text
- provenance: {'contextSize': 8192, 'durationSeconds': 2.4158938333312108, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A black number seven on a white background.
- tags:
  - number
  - black
  - white
  - seven
  - single
- textSelectionSource: vision
- title: Single Number
- usefulDetails:
  - The number is centered on the screen.

## sign-single-cjk.png

- Latency: 2.92s
- Fixture SHA256: `4a0d7685b4003dd31a9e5bdf5eee27198029bb29901a45b65605ddbfbddaed71`
- Expected: document or sign containing printed text
- limitations:
  - The exact meaning of the symbol is not specified.
- provenance: {'contextSize': 8192, 'durationSeconds': 2.9028534583339933, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A single black character symbol on a white background.
- tags:
  - symbol
  - character
  - black
  - white
  - single
- textSelectionSource: vision
- title: A single character symbol
- usefulDetails:
  - The symbol is composed of two vertical lines and two curved lines.

## sign-stop.png

- Latency: 2.79s
- Fixture SHA256: `a8d4951b8433f063384331f18b34bce89b96f08800072c1b88f4cc683be81d3d`
- Expected: document or sign containing printed text
- provenance: {'contextSize': 8192, 'durationSeconds': 2.7688018749977346, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- recognizedText:
  - STOP
- selectedTextLines:
  - STOP
- summary: A single word in black text is displayed on a plain white background.
- tags:
  - text
  - white
  - black
  - stop
  - font
- textSelectionSource: appleIntelligence
- title: Black text on white background
- usefulDetails:
  - The text is centered within the image.

## storm-coast.jpg

- Latency: 2.84s
- Fixture SHA256: `22bda77d95312b21c689b819376dd48912bef8c101d58fa97c5224f686ca7997`
- Expected: dark storm clouds above sea; bright opening in cloud; dark shoreline
- Fixture note: Expected features manually inspected from fixture contact sheet. Avoid asserting exact location, weather prediction, or time of day beyond visible lighting.
- provenance: {'contextSize': 8192, 'durationSeconds': 2.8205689166643424, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A beach with a dark sky and a body of water. The sky is filled with clouds.
- tags:
  - beach
  - clouds
  - sky
  - water
  - dark
- textSelectionSource: vision
- title: A dark beach under a cloudy sky.
- usefulDetails:
  - The clouds appear to be moving across the sky.

## table-repeated-values.png

- Latency: 4.28s
- Fixture SHA256: `b917ef22a958c5a41fcfa740e37d904b849161230525c1d6d1797899bfe5541b`
- Expected: three fruit rows with repeated quantity 1 and price $2.00; total 3 and $6.00; visible grid
- limitations:
  - The exact layout of the table's borders is not specified.
- provenance: {'contextSize': 8192, 'durationSeconds': 4.266430916668469, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- recognizedText:
  - ITEM
  - Apples
  - Pears
  - Plums
  - TOTAL
  - QTY
  - 1
  - 1
  - 1
  - 3
  - PRICE
  - $2.00
  - $2.00
  - $2.00
  - $6.00
- selectedTextLines:
  - ITEM
  - QTY
  - PRICE
- summary: A two-dimensional table lists fruit items, their quantities, and prices. The table includes a total row summarizing the count and cost.
- tags:
  - table
  - fruits
  - quantities
  - prices
  - total
- textSelectionSource: appleIntelligence
- title: Fruit inventory table
- usefulDetails:
  - The total quantity is three items.

## unreadable-abstract.png

- Latency: 3.69s
- Fixture SHA256: `1edce639279c0e0d69554939ad363e5d6a80b093d63fa3bd4a187edcc88a0684`
- Expected: blurred gray abstract texture with muted colored streaks; no readable text or identifiable objects
- Fixture note: Do not invent words, people, or scene.
- limitations:
  - The exact length of the lines is uncertain due to the blurred edges.
- provenance: {'contextSize': 8192, 'durationSeconds': 3.6702025000013236, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A two-dimensional background with a smooth gradient of colors. Two faint, curved lines of color extend from opposite corners.
- tags:
  - gradient
  - curved lines
  - abstract
  - color
  - background
- textSelectionSource: vision
- title: Abstract Color Gradient
- usefulDetails:
  - The lines appear to converge at a central point, but their exact origin is unclear.

## valley-river.jpg

- Latency: 3.33s
- Fixture SHA256: `6154d90fcbe32811a385ba6c33a295b10ff23302dd288fad43f2022b36db6c99`
- Expected: calm river with reflections; tall conifer trees; steep pale rock mountains
- Fixture note: Expected features manually inspected from fixture contact sheet. Avoid asserting exact location, weather prediction, or time of day beyond visible lighting.
- provenance: {'contextSize': 8192, 'durationSeconds': 3.3116922916669864, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A forest of trees surrounds a body of water near a mountain. The water reflects the sky and the trees.
- tags:
  - forest
  - mountain
  - water
  - trees
  - landscape
- textSelectionSource: vision
- title: A scenic forest and mountain landscape.
- usefulDetails:
  - The forest appears dense with numerous trees.

## winter-camp.jpg

- Latency: 3.25s
- Fixture SHA256: `ad6b6b7e1c0d23839f9c1e72d64bcf06485909d2fb30e9a5bd370968f751901e`
- Expected: yellow tents in snowy mountains; rock boundary or wall; snow and blue sky
- Fixture note: Expected features manually inspected from fixture contact sheet. Avoid asserting exact location, weather prediction, or time of day beyond visible lighting.
- limitations:
  - The exact shape of the stone wall is unclear due to the angle.
- provenance: {'contextSize': 8192, 'durationSeconds': 3.2319929166660586, 'modelName': 'AFM 3 Core Advanced', 'promptVersion': 5}
- summary: A yellow tent is situated in a snow-covered area, surrounded by a stone wall and mountains.
- tags:
  - tent
  - snow
  - mountains
  - landscape
  - winter
- textSelectionSource: vision
- title: Snowy mountain landscape with a tent
- usefulDetails:
  - The tent is partially covered with snow.
