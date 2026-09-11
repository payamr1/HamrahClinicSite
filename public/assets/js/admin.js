/* ============================================================
   پنل — جاوااسکریپت کوچک و اختیاری

   هر چیزی که اینجاست فقط کار را راحت‌تر می‌کند؛ اگر اجرا نشود،
   فرم‌ها همچنان کامل کار می‌کنند. هیچ منطقی اینجا نیست که سمت
   سرور تکرار نشده باشد.
   ============================================================ */
(function () {
  'use strict';

  /* ---- فیلتر زنده‌ی فهرست تگ‌ها ---------------------------- */
  var filter = document.querySelector('.tag-filter');
  if (filter) {
    var rows = Array.prototype.slice.call(document.querySelectorAll('.trow'));

    filter.addEventListener('input', function () {
      var q = filter.value.trim().toLowerCase();
      rows.forEach(function (row) {
        var name = (row.dataset.name || '').toLowerCase();
        // موردی که تیک خورده همیشه دیده شود، وگرنه کاربر فکر می‌کند پاک شده
        var checked = row.querySelector('input[type=checkbox]').checked;
        row.classList.toggle('hide', q !== '' && !checked && name.indexOf(q) === -1);
      });
    });
  }

  /* ---- برجسته‌کردن ردیف تیک‌خورده -------------------------- */
  document.querySelectorAll('.trow input[type=checkbox], .site-tag input[type=checkbox]')
    .forEach(function (box) {
      var row = box.closest('.trow') || box.closest('.site-tag');
      box.addEventListener('change', function () {
        row.classList.toggle('on', box.checked);
      });
    });

  /* ---- انتخاب نقش یعنی همان مورد تگ خورده است -------------- */
  document.querySelectorAll('.roles input[type=radio]').forEach(function (radio) {
    radio.addEventListener('change', function () {
      var row = radio.closest('.trow');
      var box = row && row.querySelector('input[type=checkbox]');
      if (box && !box.checked) {
        box.checked = true;
        row.classList.add('on');
      }
    });
  });

  /* ---- ناحیه‌ی فایل: نام فایل‌های انتخاب‌شده --------------- */
  var drop = document.querySelector('.drop');
  if (drop) {
    var input = drop.querySelector('input[type=file]');
    var label = drop.querySelector('b');
    var original = label ? label.textContent : '';

    input.addEventListener('change', function () {
      var n = input.files ? input.files.length : 0;
      drop.classList.toggle('has', n > 0);
      if (!label) { return; }
      if (n === 0)      { label.textContent = original; }
      else if (n === 1) { label.textContent = input.files[0].name; }
      else              { label.textContent = n + ' فایل انتخاب شد'; }
    });

    ['dragenter', 'dragover'].forEach(function (ev) {
      drop.addEventListener(ev, function (e) { e.preventDefault(); drop.classList.add('over'); });
    });
    ['dragleave', 'drop'].forEach(function (ev) {
      drop.addEventListener(ev, function () { drop.classList.remove('over'); });
    });
  }

  /* ---- تأیید پیش از کار برگشت‌ناپذیر ----------------------- */
  document.querySelectorAll('[data-confirm]').forEach(function (el) {
    el.addEventListener('click', function (e) {
      if (!window.confirm(el.dataset.confirm)) {
        e.preventDefault();
      }
    });
  });
})();

/* ============================================================
   شمارش معکوس دکمه‌ی «ارسال دوباره»

   سرور خودش فاصله‌ی اجباری را نگه می‌دارد؛ این فقط عدد را جلوی
   چشم کاربر می‌آورد تا نداند چرا دکمه کار نمی‌کند.
   ============================================================ */
(function () {
  'use strict';

  var btn = document.querySelector('button.link[data-wait]');
  if (!btn) { return; }

  var left = parseInt(btn.dataset.wait, 10) || 0;
  var fa   = function (n) {
    return String(n).replace(/[0-9]/g, function (d) { return '۰۱۲۳۴۵۶۷۸۹'[+d]; });
  };

  var tick = setInterval(function () {
    left -= 1;
    if (left <= 0) {
      clearInterval(tick);
      btn.disabled = false;
      btn.textContent = 'ارسال دوباره‌ی کد';
      return;
    }
    btn.textContent = 'ارسال دوباره تا ' + fa(left) + ' ثانیه';
  }, 1000);
})();
