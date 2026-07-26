(function(){
  // typing effect on the terminal line (text comes from data-type)
  var el = document.getElementById('typeline');
  if(el){
    var text = el.getAttribute('data-type') || '';
    var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if(reduced){
      el.textContent = text;
    } else {
      var i = 0;
      (function tick(){
        if(i <= text.length){
          el.textContent = text.slice(0, i++);
          setTimeout(tick, 45);
        }
      })();
    }
  }

  // reveal cards on scroll
  var cards = document.querySelectorAll('.card');
  var io = new IntersectionObserver(function(entries){
    entries.forEach(function(e){
      if(e.isIntersecting){ e.target.classList.add('in'); io.unobserve(e.target); }
    });
  }, {threshold:0.12});
  cards.forEach(function(c){ io.observe(c); });
})();
