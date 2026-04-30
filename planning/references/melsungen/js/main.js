var site = {}

// break point vars
var $xxlmin = 1280;
var $md = 768;
// break point vars
site.MOBILENEWSLISTINGWIDGETCONTENTORGANSIEMODULETYPE1 = function () {
  jQuery('.content-organiser-module-type-1 .news-listging-widget').matchHeight({byRow: false});
}

site.TABSWITCHER = function () {
jQuery('.switcher-module').each(function () {



  jQuery(this).find('.switch-item').click(function () {
    var WIDTH = jQuery(this).find('.active').parent().width();
    var POSITION = jQuery(this).find('.active').parent().position();

    

    jQuery(this).parents('.switcher-module').find('.running-active-back').width(WIDTH);
    jQuery(this).parents('.switcher-module').find('.running-active-back').css('left', POSITION.left);
  });


  jQuery(this).find('.switch-item').hover(function () {
    var WIDTH = jQuery(this).width();
    var POSITION = jQuery(this).position();

    

    jQuery(this).parents('.switcher-module').find('.ball').width(WIDTH);
    jQuery(this).parents('.switcher-module').find('.ball').css('left', POSITION.left);
  });
  




  jQuery(this).find('.switch-item .active').each(function () {
    var WIDTH = jQuery(this).parent().width();
    var POSITION = jQuery(this).parent().position();

 

    jQuery(this).parents('.switcher-module').find('.running-active-back').width(WIDTH);
    jQuery(this).parents('.switcher-module').find('.running-active-back').css('left', POSITION.left);
  });

 



});


};

// GLOBALTABMOBILECONVERTEDSLIDERtype two
site.GLOBALTABMOBILECONVERTEDSLIDERTYPETWO = function () {

  jQuery('.global-tab-mobile-converted-slider-type-two').each(function(){

    jQuery(this).find('.tab-mobile-main-slider-navigate-wrap').addClass('carousel-navigate-with-header');
  
    jQuery(this).find('.tab-mobile-main-slider .the-slider').removeAttr('class').attr('class', '');
    jQuery(this).find('.tab-mobile-main-slider > div').addClass('the-slider global-carousel equal-height-item two-column-global-carousel global-carousel-type-6 element-gap element-gap-type-4 type-arrow-pagination-view-1');
    
  
    
    jQuery(this).find('.tab-mobile-main-slider .the-slider .my-col').removeAttr('class').attr('class', '');
    jQuery(this).find('.tab-mobile-main-slider .the-slider > div').addClass('item');
  
  
      
    
  });
};

// GLOBALTABMOBILECONVERTEDSLIDER
site.GLOBALTABMOBILECONVERTEDSLIDER = function () {



jQuery('.global-tab-mobile-converted-slider').each(function(){

  jQuery(this).find('.tab-mobile-main-slider-navigate-wrap').addClass('carousel-navigate-with-header');

  jQuery(this).find('.tab-mobile-main-slider .the-slider').removeAttr('class').attr('class', '');
  jQuery(this).find('.tab-mobile-main-slider > div').addClass('the-slider global-carousel equal-height-item two-column-global-carousel global-carousel-type-1 element-gap element-gap-type-4 type-arrow-pagination-view-1');
  

  
  jQuery(this).find('.tab-mobile-main-slider .the-slider .my-col').removeAttr('class').attr('class', '');
  jQuery(this).find('.tab-mobile-main-slider .the-slider > div').addClass('item');


    
  
});



jQuery('.global-carousel-type-1, .global-carousel-type-2, .global-carousel-type-3, .global-carousel-type-4, .global-carousel-type-7, .global-carousel-type-8').parents('.section-row').addClass('overflow-hidden');


};
// GLOBALTABMOBILECONVERTEDSLIDER

// GLOBALTABMOBILECONVERTEDPRICINGBOXSLIDER
site.GLOBALTABMOBILECONVERTEDPRICINGBOXSLIDER = function () {



  jQuery('.mobile-pricing-box-slider').each(function(){

    var $carousel = jQuery(this).find('.main-carousel');

    jQuery(this).parents('.section-row').addClass('overflow-hidden');
  
     jQuery(this).find('.mobile-sliding-item > .main-wrap > .my-row').removeClass('row my-row default-row');
     jQuery(this).find('.mobile-sliding-item .carousel-cell').removeClass('col-auto my-col');


     $carousel.flickity({
      cellAlign: 'left',
      contain: true,
      pageDots: false,
      prevNextButtons: false,
      freeScroll: true,
    });

    

    

    
    
  });
  
  
  };
  // GLOBALTABMOBILECONVERTEDPRICINGBOXSLIDER

  // GLOBALFILTER
  site.GLOBALFILTER = function () {

    jQuery('.static-filter-module').each(function(){

      var STATICFILTERTRIGGER = jQuery(this).find('.item-with-hidden-check-radio input');
      var PARENT = jQuery(this).find('.result-parent');


      jQuery(STATICFILTERTRIGGER).click(function() {
        if (this.id == 'all') {
          jQuery('PARENT > .resulted-row').fadeIn(450);
        } else {
          var $el = jQuery('.' + this.id).fadeIn(450);
          jQuery(this).parents('.static-filter-module').find('.result-parent > .resulted-row').not($el).hide();
        }
        STATICFILTERTRIGGER.removeClass('active');
        jQuery(this).addClass('active');

        if(jQuery(this).is(':checked')) {
          var CHECKEDTEXT = jQuery(this).parent('.dropdown-item').find('span').text();
          jQuery(this).parents('.dropdown').find('.dropdown-toggle span').text(CHECKEDTEXT);
      }
      });


      
    });
   

    
  };  
  // GLOBALFILTER

  // responsive scrolable table
  
  site.RESPONSIVETABLEHEIGHT = function () {
    jQuery('.has-td-min-hieght tr').each(function(){
      var HEIGHT = jQuery(this).find('td:not(.fix-item)').height();
      jQuery(this).find('td.fix-item').height(HEIGHT + 30);
    });
  };
  // responsive scrolable table


  // responsive MOBILESUBMENUFUNCTION
  
  site.MOBILESUBMENUFUNCTION = function () {
    jQuery('.main-nav li.has-sub-menu a').click(function(){
      jQuery(this).parent().find('.sub-item').show();
      jQuery(this).parent().find('.sub-item').addClass('slideInRight');
      jQuery(this).parent().find('.sub-item').removeClass('slideOutRight');
    });
    jQuery('.main-nav li.has-sub-menu .responsive-menu-back').click(function(){
      jQuery(this).parents('.sub-item').addClass('slideOutRight');
      jQuery(this).parents('.sub-item').removeClass('slideInRight');
    });
  };
  // responsive MOBILESUBMENUFUNCTION


   // desktop SUBMENUFUNCTION
  
   site.DESKTOPSUBMENUFUNCTION = function () {
    

    jQuery('.main-nav li.parent-menu > a').mouseenter(function(e){

      jQuery('.main-nav li.parent-menu > a').not(this).parent().find('.sub-item').removeClass('active');
      jQuery(this).parent().removeClass('inactive');

      jQuery(this).parent().find('.sub-item').addClass('active');
      jQuery('.main-nav li.parent-menu > a').not(this).parent().addClass('inactive');

      e.stopPropagation();
    });
    jQuery('.main-nav .nav-primary').mouseleave(function(e){

     jQuery(this).find('.sub-item').removeClass('active');
     jQuery('.main-nav li.parent-menu').removeClass('inactive');

      e.stopPropagation();
    });

    jQuery('.main-nav .sub-item a').mouseenter(function(e){


      jQuery(this).parents('.sub-item').find('a').removeClass('inactive');

      jQuery(this).parents('.sub-item').find('a').not(this).addClass('inactive');

      e.stopPropagation();
    });

    jQuery('.main-nav .sub-item').mouseleave(function(){
      jQuery(this).find('a').removeClass('inactive');
    });

  };
  // desktop SUBMENUFUNCTION


jQuery(document).ready(function(){








function isAppleDevice(){
return (
(navigator.userAgent.toLowerCase().indexOf("ipad") > -1) ||
(navigator.userAgent.toLowerCase().indexOf("iphone") > -1) ||
(navigator.userAgent.toLowerCase().indexOf("ipod") > -1)
);
}
var isAndroid = navigator.userAgent.toLowerCase().indexOf("android");
var appStoreURL = "";
if(isAndroid > -1){
jQuery('body').addClass('android-device');
jQuery('html').addClass('android-device');
}
else if( isAppleDevice() ){
jQuery('body').addClass('ios-device');
jQuery('html').addClass('ios-device');

  // jQuery( window ).on( "orientationchange", function( event ) {
  //   location.reload();
  // });


}





//Check Mobile Devices
var checkMobile = function(){

    //Check Device
    var isTouch = ('ontouchstart' in document.documentElement);

    //Check Device //All Touch Devices
    if ( isTouch ) {

        jQuery('body').addClass('touch');

        

    }
    else {

        jQuery('body').addClass('no-touch');

    };

};

//Execute Check
checkMobile();


currLoc = $(location).attr('href');
jQuery('#current-url').html(currLoc);


// text copy
jQuery('.copy-function-present-url').copyOnClick({

  confirmShow:true,
  copyMode:"html",
  confirmClass:"copy-confirmation",
  confirmText:"Link Copied",
  confirmTime: 3,
  

  
});


// breadcrumb-section
var breadcrumbNextClass = $('.breadcrumb-section').next('.section-row').find('.container > div:first-child').attr('class');
$('.breadcrumb-section .breadcrumb-container').addClass(breadcrumbNextClass);

// mobile convert slider
if ($(window).width() < $xxlmin) {
site.GLOBALTABMOBILECONVERTEDSLIDER();
site.GLOBALTABMOBILECONVERTEDPRICINGBOXSLIDER();
};

// only mobile convert slider
if ($(window).width() < $md) {
  site.GLOBALTABMOBILECONVERTEDSLIDERTYPETWO();
};

// responsive MOBILESUBMENUFUNCTION
if ($(window).width() < $xxlmin) {
  site.MOBILESUBMENUFUNCTION();
};

// html filter
site.GLOBALFILTER();


// global vars
var HEADERHEIGHT = jQuery('header.header').height();







// object notation




site.HEADERSCROLLFUNCTION = function () {




  if (jQuery(document).scrollTop() > 10) {
    jQuery('header.header').addClass('header-scrolled');
  }
  else {
    jQuery('header.header').removeClass('header-scrolled');
  }



};






jQuery(window).resize(function(){


});



jQuery( window ).on( "orientationchange", function( event ) {

   
          
});

jQuery(window).scroll(function () {
  site.HEADERSCROLLFUNCTION();
});



// very begining run
jQuery('.no-default-table').find('.contenttable').removeClass('contenttable');


// site-accordion-module
jQuery('.contenttable').wrap('<div class="table-responsive"><div class="match-table view-1 layout-2 mobile-view-2"><div></div>');







// set back

jQuery('.set-back').each(function(){

 var SETBACK = jQuery(this).find('img').attr('src');
  jQuery(this).css('background-image', 'url(' + SETBACK + ')');

});










jQuery('.touch .has-submenu > a').addClass('dual-click');
   
   jQuery(document).on( "click", ".dual-click", function(event) {
        
        jQuery(".dual-click").not(this).removeClass("clicked");
        jQuery(this).toggleClass("clicked");
        if (jQuery(this).hasClass("clicked")) {
            event.preventDefault();
        }
    });


// go top
 jQuery('.go-top').click(function(){
   jQuery('html, body').animate({scrollTop: 0}, 400);
  
});


// global carousel
jQuery('.global-carousel:not(.counter-hidden)').each(function(){


var $globalCarousel = jQuery(this);


if ($globalCarousel.length) {
  var currentSlide;
  var slidesCount;
  var sliderCounter = document.createElement('div');
  sliderCounter.classList.add('slider__counter');
  
  var updateSliderCounter = function(slick, currentIndex) {
    currentSlide = slick.slickCurrentSlide() + 1;
    slidesCount = slick.slideCount;
    $(sliderCounter).html('<span>'+currentSlide+'</span>'+ '<span>'+'/'+'</span>' +'<span>'+slidesCount+'</span>');
  };

  $globalCarousel.on('init', function(event, slick) {
    $globalCarousel.append(sliderCounter);
    updateSliderCounter(slick);
  });

  $globalCarousel.on('afterChange', function(event, slick, currentSlide) {
    updateSliderCounter(slick, currentSlide);
  });
}

});

jQuery('.global-carousel-type-1').slick({
  infinite: true,
  slidesToShow: 2,
  slidesToScroll: 1,
  touchThreshold: 500,
  responsive: [
    {
      breakpoint: 767,
      settings: {
        slidesToShow: 1
      }
    }
  ]
});
jQuery('.global-carousel-type-2').slick({
  infinite: true,
  slidesToShow: 3,
  slidesToScroll: 1,
  touchThreshold: 500,
  responsive: [
    {
      breakpoint: 767,
      settings: {
        slidesToShow: 2
      }
    }
  ]
});
jQuery('.global-carousel-type-3').slick({
  infinite: true,
  slidesToShow: 4,
  slidesToScroll: 1,
  touchThreshold: 500,
  responsive: [
    {
      breakpoint: 767,
      settings: {
        slidesToShow: 1
      }
    },
    {
      breakpoint: 1280,
      settings: {
        slidesToShow: 2
      }
    }
  ]
});

jQuery('.global-carousel-type-4').slick({
  infinite: true,
  slidesToShow: 3,
  slidesToScroll: 1,
  touchThreshold: 500,
  responsive: [
    {
      breakpoint: 767,
      settings: {
        slidesToShow: 1
      }
    }
  ]
});
jQuery('.global-carousel-type-4').each(function(){
  var ITEM = jQuery(this).find('.item').length;
  if(ITEM <= 3 ){
    jQuery(this).addClass('in-tab-no-upcoming-seen');
  }
});

jQuery('.global-carousel-type-5').slick({
  infinite: true,
  slidesToShow: 1,
  slidesToScroll: 1,
});


jQuery('.global-carousel-type-6').slick({
  infinite: true,
  slidesToShow: 3,
  slidesToScroll: 1,
  touchThreshold: 500,
  responsive: [
    {
      breakpoint: 767,
      settings: {
        slidesToShow: 1
      }
    }
  ]
});




jQuery('.global-carousel-type-7').slick({
  infinite: true,
  slidesToShow: 4,
  slidesToScroll: 1,
  touchThreshold: 500,
  responsive: [
    {
      breakpoint: 767,
      settings: {
        slidesToShow: 1
      }
    },
    {
      breakpoint: 1280,
      settings: {
        slidesToShow: 3
      }
    }
  ]
});


jQuery('.global-carousel-type-8').slick({
  infinite: true,
  slidesToShow: 3,
  slidesToScroll: 1,
  touchThreshold: 500,
  responsive: [
    {
      breakpoint: 767,
      settings: {
        slidesToShow: 2
      }
    }
  ]
});

jQuery('.download-carousel-wrap').parents('section.section-row').removeClass('section-row');

jQuery('.type-arrow-pagination-view-1').each(function(){
  jQuery(this).find('.slick-arrow').wrapAll('<div class="slider-arrow-holder"></div>');
  jQuery(this).find('.slider__counter, .slider-arrow-holder').wrapAll('<div class="global-carousel-slider-navigate-wrap"></div>');
  var WRAPPARENT = jQuery(this).find('.global-carousel-slider-navigate-wrap');
  jQuery(this).find('.slider__counter').detach().prependTo(WRAPPARENT);
});

jQuery('.global-carousel-slider-navigate-wrap').each(function(){
  var NAVIGATEPLACE = jQuery(this).parents('.section-row, .download-carousel-wrap').find('.carousel-navigate-with-header');
  jQuery(this).detach().appendTo(NAVIGATEPLACE);
});






// menu trigger
jQuery('.header-menu .menu-trigger').click(function(){
  jQuery('.header-search, .header-logo-holder').hide();
  jQuery(this).addClass('clicked');
  jQuery('.main-nav.slide-action').show();
  jQuery('.header-search .responsive-search-trigger, .header-primary-menu, .header-search').addClass('inactive');
  jQuery('body').addClass('overflow-hidden');
});

jQuery('.independent-menu-close').click(function(){
  jQuery('.header-search, .header-logo-holder').show();
  jQuery(this).removeClass('clicked');
  jQuery('.main-nav.slide-action').hide();
  jQuery('.header-search .responsive-search-trigger, .header-primary-menu, .header-search').removeClass('inactive');
  jQuery('body').removeClass('overflow-hidden');
});

// fancybox
Fancybox.bind('[data-fancybox]', {
  Html : {
    youtube: {
      controls: 0,
      rel: 0,
      fs: 0
    }
  }
});   

// page anchoring
$(document).on('click', '.anchor-link', function (event) {
  event.preventDefault();

  $('html, body').animate({
      scrollTop: $($.attr(this, 'href')).offset().top - (HEADERHEIGHT + 40)
  }, 100);
});

// filter navigation slider
jQuery('.filter-navigation-slider .the-slider').each(function(){

  jQuery(this).slick({
    infinite: true,
    slidesToShow: 7,
    slidesToScroll: 1,
    arrows: true,
    dots: false,
    draggable: false,
    initialSlide: 0
  });

  jQuery(this).find('.slick-arrow').wrapAll('<div class="global-carousel-slider-navigate-wrap"><div class="slider-arrow-holder"></div></div>');

});


// item-with-hidden-check-radio
  jQuery('.item-with-hidden-check-radio input').click(function(){
    jQuery(this).parent().trigger('click');
  });


// player-detail-info-module 
if ($(window).width() >= $xxlmin) {
jQuery('.player-detail-info-module .info-table.parent-table table').each(function(){
  var WIDTH = jQuery(this).width();
  jQuery(this).parents('.player-detail-info').find('.info-table.child-table table').width(WIDTH);
});
}


// primary btn
jQuery('.primary-btn').addClass('site-btn');
jQuery('.content-btn').addClass('site-btn primary-btn no-default-arrow down-arrow-icon-light anchor-link');
jQuery('.download-btn').addClass('site-btn primary-btn no-default-arrow download-icon-light');
jQuery('.download-btn').attr('download', 'download');


// reset typo3 default setup
jQuery('figure.table').removeClass('table');
jQuery('.pricing-content table').find('th, td').wrapInner('<p></p>');
jQuery('.frame-type-form_formframework .form-navigation button').addClass('site-btn primary-btn');
jQuery('.frame-type-form_formframework .form-navigation button').removeClass('btn btn-primary');


// powermail forms
jQuery('.tx-indexedsearch-searchbox').each(function(){
  jQuery(this).find('.tx-indexedsearch-form').addClass('form-group mb-3');
  jQuery(this).find('label').addClass('form-label');
  jQuery(this).find('input[type="text"]').wrap('<div class="input"></div>');
  jQuery(this).find('input[type="text"]').addClass('form-control');
  jQuery(this).find('.tx-indexedsearch-searchbox-button').addClass('site-btn primary-btn');
});
jQuery('.tx-indexedsearch-browsebox').each(function(){
  jQuery(this).addClass('grid-flex-justify-content-center filter-result-pagination');
  jQuery(this).find('li').addClass('number-pagi');
  jQuery(this).parents('.content-box').addClass('filter-module');
  jQuery(this).find('li strong').parent().addClass('current disabled');
  jQuery(this).find('.tx-indexedsearch-browselist-next:first-child a').html('<i class="fa fa-angle-double-left"></i>');
  jQuery(this).find('.tx-indexedsearch-browselist-next:last-child a').html('<i class="fa fa-angle-double-right"></i>');
});


// responsive-search-trigger
jQuery('.responsive-search-trigger').click(function(){
  jQuery(this).toggleClass('triggered');
  jQuery('.header-search .field-holder').toggleClass('mobile-toggle-view');
});



// desktop function delare
if ($(window).width() >= $xxlmin) {
  site.DESKTOPSUBMENUFUNCTION();
};






});








// load
jQuery(window).load(function(){

  // getMaxChildWidth
  function getMaxChildWidth(sel) {
    max = 0;
    jQuery(sel).children().each(function(){
        c_width = parseInt($(this).width());
        if (c_width > max) {
            max = c_width;
        }
    });
    return max;
  }

// nav max width
jQuery('.nav-items-wrap').each(function(){
  var THIS = jQuery(this);
  var ORIGINALWIDTH = jQuery(this).width();
  var MAXWIDTHNAVSUB = getMaxChildWidth(jQuery(THIS).find('.sub-item'));
  var SUBTRACTWIDTHFORPAD = MAXWIDTHNAVSUB + 107;
  var NAVWRAPHEIGHT = jQuery(this).height();
  // console.log(MAXWIDTHNAVSUB);
  jQuery(this).find('.sub-item').width(MAXWIDTHNAVSUB + 10);
  jQuery(this).find('.sub-item').css('min-height', NAVWRAPHEIGHT);
  jQuery(this).width(MAXWIDTHNAVSUB + ORIGINALWIDTH + 107);
  // jQuery(this).find('.parent-menu').css('padding-right', SUBTRACTWIDTHFORPAD);
});
jQuery('.nav-primary').each(function(){
 var WIDTH = jQuery(this).width();
 var SUBITEMWIDTH = jQuery(this).find('.sub-item').width();
 jQuery('.nav-secondary').width(WIDTH);
 jQuery('.nav-secondary .sub-item').width(SUBITEMWIDTH);
});

// menu slide
jQuery('.main-nav.slide-action').addClass('loaded fadeOutUp');



// match height
  jQuery('.equal-row').each(function() {
       jQuery(this).children('.equal-block').matchHeight();
  });

  jQuery('.element-row').each(function() {
       jQuery(this).children('.equal-block').matchHeight();
  });

  jQuery('.get-grid-main-module-height .the-main-module').matchHeight();

//   jQuery('.get-grid-main-module-height').each(function() {
//     jQuery(this).children('.the-main-module').matchHeight();
// });

  jQuery('.equal-card-header .the-card-header').matchHeight();

  jQuery('.global-carousel.equal-height-item .item').matchHeight();

  jQuery('.pricing-box-module .pricing-header').matchHeight({byRow: false});
  jQuery('.pricing-box-module .pricing-box').matchHeight({byRow: false});

  jQuery('.news-widget-match-height-type-1 .news-title').matchHeight();
  jQuery('.news-widget-match-height-type-1').matchHeight({byRow: false});

  jQuery('.download-module .download-item').matchHeight();
  


  jQuery('.employee-card-module .employee-basic-info').matchHeight();





// adapt-height-parent-50
jQuery('.adapt-height').parent('.the-main-module').addClass('adapt-height-parent-50-default-grid adapt-height-default-grid');
jQuery('.adapt-height-parent-50-default-grid').each(function(){
  var HEIGHT = jQuery(this).height();
  jQuery(this).find('.adapt-height').height((HEIGHT/2) - 10);
});

var siteLoad = {}




siteLoad.CAPTIONSLIDERHEIGHT = function() {

  
    

};   




jQuery(window).resize(function(){


});


// teaser module min height
jQuery('.teaser-module.has-min-height:not(.get-this-height)').each(function(){
  var HEIGHT = jQuery(this).parents('.the-main-module').height();
  jQuery(this).height(HEIGHT);
});
jQuery('.teaser-module.has-min-height.get-this-height').each(function(){
  var HEIGHT = jQuery(this).height();
  jQuery(this).height(HEIGHT);
});


// responsive table
// if ($(window).width() < $xxlmin) {
//   site.RESPONSIVETABLEHEIGHT();
// };



// paralax
var controller = $.superscrollorama();
jQuery('.paralax-pause-scroller.pause-scroller-type-1').each(function () {  
  var PARENTS = jQuery(this);

  var reactiveItem1 = jQuery(this).find('.reactive-item-type-1');

  // TweenMax.from(ferris, 0, { rotation:0, yoyo:true, repeat:-1, ease:Linear.easeNone } );
  // TweenMax.to(ferris, 10, { rotation:360, yoyo:true, repeat:-1, ease:Linear.easeNone } );
  
  var paralaxCard = TweenMax.to(
    $(PARENTS).find(reactiveItem1), 0.1, { rotation:0, }
  );
  var paralaxCard = TweenMax.to(
    $(PARENTS).find(reactiveItem1), 0.1, { rotation:180, }
  );
  controller.pin(PARENTS, 900, { offset: -900, anim: paralaxCard });
  
});




// switcher
site.TABSWITCHER();


// only mobile load notation declaration
if ($(window).width() < $md) {
  // site.MOBILENEWSLISTINGWIDGETCONTENTORGANSIEMODULETYPE1();
};


// responsive-scrollable-table
jQuery('.responsive-scrollable-table').each(function(){
  jQuery(this).find('thead th:last-child').addClass('arrow-overlap');
  jQuery(this).find('thead th.left-right-gap-creator:last-child').prev('th').addClass('arrow-overlap');
});


// hb-embed__table
setTimeout(function () {
  jQuery('.hb-embed__table').each(function(){
    jQuery(this).addClass('contenttable');
    jQuery(this).parent('.hb-embed').addClass('match-table view-1 layout-2 mobile-view-2');
    jQuery(this).parent('.hb-embed').wrap('<div class="table-responsive"></div>');
  });
}, 100);



});

