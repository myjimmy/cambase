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
   e.stopPropagation()
   $('body').modalmanager('loading')
   $.rails.handleRemote( $(this) )

#removes whatever is in the modal body content div upon clicking close/outside modal
$(document).on 'click', '[data-dismiss=modal], .modal-scrollable', ->
  $('.modal-body-content').empty()
$(document).on 'click', '#signin-modal', (e) ->
  e.stopPropagation()

$ ->
  $('.clickable a').each ->
    target = $(this)
    target.attr('href', target.attr('data-href'))
    if target.attr('data-target') == "_blank"
      target.attr('target', "_blank")

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
    if ( $(this).attr('checked') == 'checked' )
      image = "##{ $(this).attr('id') }_icon"
      $(image).addClass("selected")

  $('.module-images').on 'click', ".thumbnails img", (e) ->
    e.preventDefault()
    if $(this).hasClass "add-new-image"
      return
    clicked_image = $(this).attr('src')
    $('.module-image-main').attr('src', clicked_image)

  $('.module-information .editable').editable
    emptytext: 'Unknown'
    toggle: 'manual'
    mode: 'inline'
    ajaxOptions:
      type: 'PUT'

  $('.module-manufacturer .editable').editable
    emptytext: 'Unknown'
    toggle: 'manual'
    ajaxOptions:
      type: 'PUT'

  $('.visitor-signed_in .module-table td.icon-edit').on "click", (e) ->
    e.preventDefault()
    e.stopPropagation()
    $(this).closest('tr').find('.editable').editable('toggle')

  $('.visitor-signed_out .add-new-image, .visitor-signed_out .icon-edit').on 'click', (e) ->
    e.preventDefault()
    e.stopPropagation()
    $('#signin-modal').modal()

  $('.visitor-signed_in .add-new-image').on "click", (e) ->
    e.preventDefault()
    $(this).closest('.module').find('input[type="file"]').trigger('click')

  $('.module input[type="file"]').change ->
    $(this).closest('.module').find('form').submit()
