#= require jquery
#= require jquery.turbolinks
#= require jquery_ujs
#= require_tree .
#= require bootstrap
#= require editable/bootstrap-editable
#= require editable/rails

#= require get-style-property
#= require get-size
#= require matches-selector
#= require eventEmitter
#= require eventie
#= require doc-ready
#= require classie
#= require jquery-bridget
#= require matches-selector
#= require outlayer/item
#= require outlayer
#= require packery/rect
#= require packery/packer
#= require packery/item
#= require packery

# called from a bootstrap dropdown, this closes the dropdown
$('a[data-toggle=modal]').on 'click', ->
  $('.dropdown').removeClass('open')

# this sets up the ajax loader, and it will stay until the method specific js removes it
$('a[data-target=#signin-modal]').on 'click', ->
   e.preventDefault()
   e.stopPropagation();
   $('body').modalmanager('loading');
   $.rails.handleRemote( $(this) );

#removes whatever is in the modal body content div upon clicking close/outside modal
$(document).on 'click', '[data-dismiss=modal], .modal-scrollable', ->
  $('.modal-body-content').empty()
$(document).on 'click', '#signin-modal', (e) ->
  e.stopPropagation();

$.fn.editable.defaults.mode = 'inline';
$.fn.editable.defaults.ajaxOptions = {type: "PUT"};
$ ->
  $container = $('#masonry-container')
  $container.packery
    itemSelector: '.tile',
    gutter: 0

  $('#search_dropdown').on 'click', ->
    $('.search-dropdown').slideToggle()

  $(".features span").on 'click', ->
    feature_id = $(this).attr("id").replace('_icon', '')
    $("##{feature_id}").trigger "click"
    $(this).toggleClass "selected"

  $(".features input[type=checkbox]").each ->
    x = $(this).attr('checked')
    if (x == 'checked' )
      image = "##{ $(this).attr('id') }_icon"
      $(image).addClass("selected")

  $('.module-images').on 'click', ".thumbnails img", (e) ->
    e.preventDefault()
    clicked_image = $(this).attr('src')
    $('.module-image-main').attr('src', clicked_image)

  $('.editable').editable
    emptytext: 'Unknown'
