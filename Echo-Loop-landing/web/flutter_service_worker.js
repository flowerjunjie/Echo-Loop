'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"manifest.json": "5b2abd62800fe2fc1c7dc54f1eda5d2c",
"assets/assets/icon/app-icon-1024.png": "c51e03489c813b564c8d9c513b513fb3",
"assets/assets/icon/app-icon-96.png": "96b17e927985d3836d7a2319b10ab8d0",
"assets/assets/icon/app-icon-1024-alpha.png": "d5876e1594157f58eeea5117d9d4dc89",
"assets/assets/demo/CEFR%2520A2%2520-%2520Invitation%2520to%2520a%2520party.m4a": "735659dd2dbb02b240ca3ec5b544cb12",
"assets/assets/demo/CEFR%2520A1%2520-%2520Book%2520a%2520table.m4a": "953b1a82e142bad3b3b6da226e560ed8",
"assets/assets/demo/CEFR%2520B1%2520-%2520Work-life%2520balance.m4a": "6a2495c72cb3ecc31614012f8ad05ab1",
"assets/assets/demo/CEFR%2520C1%2520-%2520Rent%2520a%2520house.m4a": "7df24e5a201d87ec733b2913f0456ba4",
"assets/assets/demo/CEFR%2520C2%2520-%2520Conducting%2520yourself.m4a": "099a68b825435f5460aee90935cb1f7b",
"assets/assets/demo/CEFR%2520B2%2520-%2520Incentives.m4a": "71000a81773241c1e87246dfd1ac4579",
"assets/assets/audio/silence_2s.m4a": "d20ddc7a2722b57f162b47f3ff54f4f1",
"assets/assets/fonts/pdf/OFL.txt": "50c64292d8b855546f83619cab28d2b4",
"assets/assets/fonts/pdf/NotoSansSC-Regular.ttf": "a4bf9c8e3eb89857fb3dc56d62152c39",
"assets/assets/fonts/pdf/NotoSans-Regular.ttf": "f53b83ff53f1d2632bf4d26382469b44",
"assets/assets/fonts/pdf/NotoSans-Italic.ttf": "1b7520d4d639a1c27c45aa8b6d009737",
"assets/assets/fonts/pdf/NotoSans-Bold.ttf": "95a12ca7e42d6c5e69e630039042c33f",
"assets/AssetManifest.bin": "e4e33b75a4a6c937e81e228d17aec8aa",
"assets/NOTICES": "9d71dd7055120ee39f49a40fa6a8f968",
"assets/FontManifest.json": "c75f7af11fb9919e042ad2ee704db319",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.json": "ed1b4494ca9e2250a7856731a350efc7",
"assets/packages/purchases_flutter/assets/web/purchases_js_hybrid_mappings.js": "53d53f8d40720504a758a8632fa603d3",
"assets/packages/flutter_inappwebview_web/assets/web/web_support.js": "509ae636cfdd93e49b5a6eaf0f06d79f",
"assets/packages/wakelock_plus/assets/no_sleep.js": "7748a45cd593f33280669b29c2c8919a",
"assets/packages/flutter_inappwebview/assets/t_rex_runner/t-rex.html": "16911fcc170c8af1c5457940bd0bf055",
"assets/packages/flutter_inappwebview/assets/t_rex_runner/t-rex.css": "5a8d0222407e388155d7d1395a75d5b9",
"assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf": "ede7e2bb4ce764dadc73065bb40a1af8",
"assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Regular-400.otf": "46be639d952abe98effde36da35e7701",
"assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf": "95a2a5d8eaf824c42e2896c01b262d2c",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "1cfe85f76b56090993b04e4cc49fd312",
"assets/test/fixtures/audio_transcode/silence.mp3": "f53d6bdfc356b022191f5d3346058809",
"assets/test/fixtures/audio_transcode/silence.m4a": "2754336745e2fd88a84ab0bdbbcfaa8d",
"assets/test/fixtures/audio_transcode/silence.wav": "77173ae84ef5dadb0883b9075b329bfe",
"assets/test/fixtures/audio_transcode/silence.aac": "9b5b407abc424e1e021dbf4316c74e68",
"assets/test/fixtures/audio_transcode/silence.flac": "0e607f5c61de3c4f8708dcf395dba3fd",
"assets/test/fixtures/audio_transcode/silence_cover.mp3": "19b6aeefec8f6fdcfc3e9056501f9335",
"assets/screenshots/04-intensive.png": "ca22eeec142776cacda92f58569d28ae",
"assets/screenshots/05-analysis.png": "454ee04c620636c133fc873d3ffaec07",
"assets/screenshots/07-favorites.png": "dedee88521b6a1272c0e3ba052d5cfd0",
"assets/screenshots/02-loop.png": "ef7b6d430188660f3449a70c9ebcdeca",
"assets/screenshots/01-import.png": "2c3813051373dc1ef144fddf8dcfa59c",
"assets/screenshots/03-reminder.png": "50ed683adc39a7ca2b15def7cafe5ff1",
"assets/screenshots/09-freestyle.png": "361d61521227b0e33cdeaa8743d7491e",
"assets/screenshots/08-flashcard.png": "9cb916303ee1833a0af6a290995a7a68",
"assets/screenshots/06-retell.png": "1ab9fd7ee01ec540896bdf52634990af",
"assets/AssetManifest.bin.json": "6b12a376c11108b1e65ffef01bf662ec",
"assets/fonts/MaterialIcons-Regular.otf": "a6833eed948738c656a6637dd2d3707e",
"version.json": "f496df05cefedfecf0419f03ce31c6c6",
"favicon-48.png": "a414f6dd236c51592af10f920ab0294e",
"favicon-32.png": "707d78a8da029ae7dd7481316b286782",
"privacy.html": "4c1955169693d49d17e902768d49e5cc",
"apple-touch-icon.png": "1b7652f11b31cd79a51a014151c15b1e",
"favicon.png": "b60a968e51b44de8cca1aefc2f914257",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"apple-app-site-association": "82c1f4765b237d97f3e046b3a3494dd7",
"og-image.png": "1eb548c5b8d947662b01c151ec74fe99",
"canvaskit/webparagraph/canvaskit.js.symbols": "3184b27cda5ef5649c727c7c4f0ae31e",
"canvaskit/webparagraph/canvaskit.wasm": "8cecf3b9c2e8270502de9138a21d4e8f",
"canvaskit/webparagraph/canvaskit.js": "003f529b235d9f71c3b5e6c439330d87",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/wimp.wasm": "9173d3df97ed517649085f35f64592bf",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"canvaskit/wimp.js": "e6084b5f6628d1ffc5236f8c224750cd",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/wimp.js.symbols": "53d78ee9cde09cd3336add36d64f1c37",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"main.dart.js": "7be244918864536f5c867a1887f6636b",
"favicon-96.png": "e16119b05e82bcbbf902e8442927ce45",
"flutter_bootstrap.js": "f2901012dd8e7473b9d62627d2008345",
"terms.html": "90445dd4879269b91693080e58de916d",
"icons/Icon-maskable-192.png": "96dd8840f12bb6194df93c49ee3c381e",
"icons/Icon-512.png": "03fd6b98a486f0fa29e4b9fd16bac6c3",
"icons/Icon-maskable-512.png": "03fd6b98a486f0fa29e4b9fd16bac6c3",
"icons/Icon-192.png": "96dd8840f12bb6194df93c49ee3c381e",
"favicon-16.png": "57004b8eb9c34d5c565b7050e7d0d7a8",
"index.html": "6003b2f143bd3f2aaaf9a4904f767aa3",
"/": "6003b2f143bd3f2aaaf9a4904f767aa3"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
