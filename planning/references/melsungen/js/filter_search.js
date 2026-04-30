jQuery(document).ready(function() {
	jQuery('.sort_radio').click(function() {
		if(jQuery(this).is(':checked')) {
			var CHECKEDTEXT = jQuery(this).parent('.dropdown-item').find('span').text();
			jQuery(this).parents('.dropdown').find('.dropdown-toggle span').text(CHECKEDTEXT);
			jQuery('#tx_netzmtm_news_sort').val(jQuery(this).val());
			jQuery('#news_pageno').val(1);
			sendNewsContentRequest();
		}
  });
  jQuery('.mcategory_radio').click(function() {
		if(jQuery(this).is(':checked')) {
			  var CHECKEDTEXT = jQuery(this).parent('.dropdown-item').find('span').text();
			  jQuery(this).parents('.dropdown').find('.dropdown-toggle span').text(CHECKEDTEXT);
        var catid= jQuery(this).val();
        jQuery('#newsCategory .item').removeClass('current-item');
        jQuery('#item-category-'+catid).addClass('current-item');
        jQuery('#tx_netzmtm_news_category').val(catid);
			  jQuery('#news_pageno').val(1);
			  sendNewsContentRequest();
		}
  });

  jQuery('#newsCategory a').click(function() {
	    jQuery('#newsCategory .item').removeClass('current-item');
      jQuery(this).parent().addClass('current-item');
      jQuery('#tx_netzmtm_news_category').val(jQuery(this).data('uid'));
      jQuery('#news_pageno').val(1);
      sendNewsContentRequest();
  }); 	
  jQuery('#submitNewTitle').click(function() {
    jQuery('#news_pageno').val(1);
    sendNewsContentRequest();
  });
  
  jQuery('#tx_netzmtm_news_title').keypress(function(e){
        if(e.which == 13){
          jQuery('#news_pageno').val(1);
          sendNewsContentRequest();
          e.preventDefault();
        }
        
    });

});
function newsPagination(no){
	jQuery('#news_pageno').val(no);
	sendNewsContentRequest();
}

function sendNewsContentRequest(){
    var urlAjax = jQuery('#newsSearch').attr('action');
    var dataAjax = jQuery('#newsSearch').serialize();
    jQuery.ajax({
        url: urlAjax,
        type: 'post',
         data:dataAjax,
         beforeSend: function() {
          jQuery('#newsLoader').show();
         },
         success: function(data){
            console.log(data);
            jQuery('#newsResult').html(data.html);
			      jQuery('#newsResultPagination').html(data.htmlPage);
            jQuery('.news-widget-match-height-type-1 .news-title').matchHeight();
            jQuery('.news-widget-match-height-type-1').matchHeight({byRow: false});
        },
         complete:function(data){
          jQuery('#newsLoader').hide();
        }
   });
}