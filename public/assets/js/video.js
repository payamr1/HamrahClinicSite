/* ============================================================
   پخش ویدیوی آپارات و یوتیوب، فقط پس از کلیک.

   iframe این سرویس‌ها صدها کیلوبایت و چند کوکی شخص ثالث با خود
   می‌آورد. تا وقتی کاربر نخواسته ویدیو ببیند، هیچ‌کدام بارگذاری
   نمی‌شود. اگر این فایل اجرا نشود، noscript کاربر را مستقیم به
   صفحه‌ی ویدیو می‌برد.
   ============================================================ */
(function () {
  'use strict';

  /** نشانی تماشا را به نشانی جاسازی تبدیل می‌کند */
  function embedSrc(url) {
    var m;

    // https://www.aparat.com/v/XXXXX
    m = url.match(/aparat\.com\/v\/([A-Za-z0-9]+)/);
    if (m) { return 'https://www.aparat.com/video/video/embed/videohash/' + m[1] + '/vt/frame'; }

    // آپارات گاهی خودش نشانی embed می‌دهد
    if (/aparat\.com\/video\/video\/embed\//.test(url)) { return url; }

    // https://youtu.be/XXXX  یا  https://www.youtube.com/watch?v=XXXX
    m = url.match(/youtu\.be\/([A-Za-z0-9_-]{6,})/)
     || url.match(/youtube\.com\/watch\?(?:.*&)?v=([A-Za-z0-9_-]{6,})/);
    if (m) { return 'https://www.youtube-nocookie.com/embed/' + m[1] + '?autoplay=1'; }

    return null;
  }

  document.querySelectorAll('.vplay').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var url = btn.dataset.embed || '';
      var src = embedSrc(url);

      if (!src) {                       // نشناختیم — کاربر را نفرستیم به بن‌بست
        window.open(url, '_blank', 'noopener');
        return;
      }

      var frame = document.createElement('iframe');
      frame.src = src;
      frame.title = btn.querySelector('.vtxt') ? btn.querySelector('.vtxt').textContent.trim() : 'ویدیو';
      frame.allow = 'accelerometer; autoplay; encrypted-media; picture-in-picture; fullscreen';
      frame.allowFullscreen = true;
      frame.loading = 'lazy';
      frame.referrerPolicy = 'strict-origin-when-cross-origin';

      btn.replaceWith(frame);
    });
  });
})();
