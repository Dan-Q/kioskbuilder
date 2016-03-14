$ ->
  # Utility functions
  identity = ->
    if (typeof Android != 'undefined' and 'getSerialNumber' of Android) then return 'Kiosk-' + Android.getSerialNumber() # If KioskBrowser, identify by serial
    'Desktop-' + navigator.product # Otherwise, identify by navigator.product (like simplified user agent) so it can be filtered out

  # Google Analytics
  exhibitionTitle = $('body').data('exhibition-title')
  agentIdentity = identity()

  triggerAnalytics = (action) ->
    $('#analytics').attr 'src', 'http://www.bodleian.ox.ac.uk/__offline-analytics/' + exhibitionTitle + '/' + action + '/' + agentIdentity
    return

  $('body').append '<iframe id="analytics" height="0" width="0" src="./" style="visibility:hidden;display:none"></iframe>'

  # Automatic brightness control
  checkBrightness = ->
    autoBrightnessSupported = typeof Android != 'undefined' and 'getScreenBrightness' of Android and 'setScreenBrightness' of Android
    dayBeginsAt = $('body').data('day-begins-at')
    dayEndsAt = $('body').data('day-ends-at')
    dayBrightness = $('body').data('day-brightness')
    nightBrightness = $('body').data('night-brightness')
    currentHour = (new Date).getHours()
    if autoBrightnessSupported then currentBrightness = Android.getScreenBrightness()
    if currentHour < dayBeginsAt or currentHour >= dayEndsAt
      # night time - reduce brightness
      if autoBrightnessSupported
        if currentBrightness != nightBrightness then Android.setScreenBrightness nightBrightness
        else
      else
        console.log 'Setting brightness to ' + nightBrightness
    else
      # day time - increase brightness
      if autoBrightnessSupported
        if currentBrightness != dayBrightness then  Android.setScreenBrightness dayBrightness
      else
        console.log 'Setting brightness to ' + dayBrightness
    setTimeout checkBrightness, 30000
  checkBrightness()

  # Internal links and navigation
  goToSlide = (newSlide)->
    if ((typeof newSlide) == 'string') then newSlide = $("#pages > *[data-id=#{newSlide}]")
    oldSlide = $('#pages > *:visible')
    $('nav a').removeClass 'active'
    # if this new slide has a highlight-nab-id set or is represented by a real navigation button, mark it as clicked (if both, trigger first only)
    $("nav a[href='#{newSlide.data('highlight-nav-id')}'], nav a[href='#{newSlide.data('id')}'], nav a[href='#{newSlide.data('title')}']").first().addClass 'active'
    # if we're going to a full screen page and the menu is shown, hide it; and vice-versa
    if newSlide.data('full-screen')? && ($('nav:visible').length == 1)
      $('nav').fadeOut 200
    else if !newSlide.data('full-screen')? && ($('nav:visible').length == 0)
      $('nav').fadeIn 200
    # fade out the old page, then fade in the new page
    $('body').removeClass "slide-#{oldSlide.data('id')}-visible"
    if e = oldSlide.data('triggers-before-exit') then eval(e)
    $('#pages > *:visible').fadeOut 200
    $('body').removeClass "slide-#{oldSlide.data('id')}-loaded"
    if e = oldSlide.data('triggers-after-exit') then eval(e)
    if e = newSlide.data('triggers-before-enter') then eval(e)
    $('body').addClass "slide-#{newSlide.data('id')}-loaded"
    setTimeout ->
      newSlide.fadeIn 200, ->
        if e = newSlide.data('triggers-after-enter') then eval(e)
        $('body').addClass "slide-#{newSlide.data('id')}-visible"
    , 200
    false

  $('a').on 'click', ->
    if($(this).closest('nav').length == 1) && $(this).hasClass('active') then return false # ignore navbar clicks on current tab
    url = $(this).attr('href')
    if (newSlide = $("#pages > *[data-id=#{url}]")).length == 0 then return true # looks like a real link: process normally
    goToSlide(newSlide)

  # Video/audio player controls
  $('#video-caption, #video-progress').on 'click', ->
    video = $('.slick-active video, .slick-active audio')[0]
    if video.paused
      video.play()
    else
      video.pause()
    return

  # Make galleries with pinch-and-zoom work
  imageViewer = $('#image-viewer')
  imageViewerWrapper = $('#image-viewer-image-wrapper')
  imageViewerImage = imageViewerWrapper.find('img')
  imageViewerCaption = $('#image-viewer-caption')
  imageViewerWrapper.panzoom(
    $zoomIn: $('#image-viewer-controls .zoom-in')
    $zoomOut: $('#image-viewer-controls .zoom-out')).on 'panzoomzoom', (e, panzoom, scale, opts) ->
    captionFadeStartAtScale = 1.0
    captionFadeFinishAtScale = 1.6
    captionFadeRange = captionFadeFinishAtScale - captionFadeStartAtScale
    if scale > captionFadeStartAtScale
      if scale >= captionFadeFinishAtScale
        imageViewerCaption.css 'opacity', 0
        setTimeout (->
          if imageViewerCaption.css('opacity') == 0
            imageViewerCaption.css 'display', 'none'
          return
        ), 250
      else
        if imageViewerCaption.css('display') == 'none'
          imageViewerCaption.css 'display', 'block'
        imageViewerCaption.css 'opacity', 1 - ((scale - captionFadeStartAtScale) / captionFadeRange)
    else
      if imageViewerCaption.css('display') == 'none'
        imageViewerCaption.css 'display', 'block'
      imageViewerCaption.css 'opacity', 1
    return
  $('#image-viewer-controls .close').on 'click', ->
    # trigger analytics
    triggerAnalytics 'gallery/closeimageviewer'
    # hide imageViewer
    imageViewer.fadeOut ->
      imageViewerCaption.hide()
      imageViewerImage.hide()
      return
    false
  $('#image-viewer-controls .prev').on 'click', ->
    imageViewerCaption.hide()
    imageViewerImage.hide()
    $('.gallery-item').removeClass 'zoomed'
    imageViewer.data('prev').addClass('zoomed').click()
    false
  $('#image-viewer-controls .next').on 'click', ->
    imageViewerCaption.hide()
    imageViewerImage.hide()
    $('.gallery-item').removeClass 'zoomed'
    imageViewer.data('next').addClass('zoomed').click()
    false
  $('.gallery-section img').each (e) ->
    $('body').append '<img class="precached-gallery-image" src="' + $(this).data('full-src') + '" />'
    return

  ### Old Masonry stuff
  $('.gallery-section').each ->
    narrowestImage = 99999
    $(this).find('img').each ->
      $(this).wrap '<div class="gallery-item" data-id="' + $(this).attr('id') + '"></div>'
      $(this).after $(this).data('desc')
      return
    masonryGrid = $(this).masonry(
      itemSelector: '.gallery-item'
      columnWidth: 214
      gutter: 0
      isFitWidth: true)
    masonryGrid.on 'click', '.gallery-item', ->
      if $(this).is('.zoomed')
        # trigger analytics
        triggerAnalytics 'gallery/' + $(this).data('id') + '/imageviewer'
        # already zoomed - open viewer
        imageViewer.data('next', $(this).next()).data('prev', $(this).prev()).show().css 'background-position-x', 'center'
        if imageViewer.data('next').length > 0
          imageViewer.find('.next').show()
        else
          imageViewer.find('.next').hide()
        if imageViewer.data('prev').length > 0
          imageViewer.find('.prev').show()
        else
          imageViewer.find('.prev').hide()
        fullSrc = $(this).find('img').data('full-src')
        caption = $(this).find('img').data('caption')
        setTimeout (->
          imageViewerImage.attr('src', fullSrc).css
            width: ''
            height: ''
            'margin-top': ''
            'martin-left': ''
          if ! !/-WIDE/.exec(fullSrc)
            # images whose aspect ratio makes them wider than the screen if they're as tall should have "-WIDE" in their filename
            imageViewerImage.attr('src', fullSrc).css 'width', $(window).width()
            setTimeout (->
              # reposition image in frame
              imageViewerImage.css 'margin-top', ($(window).height() - $('#image-viewer-image-wrapper img').height()) / 2
              return
            ), 100
          else
            imageViewerImage.attr('src', fullSrc).css 'height', $(window).height()
            setTimeout (->
              # reposition image in frame
              imageViewerImage.css 'margin-left', ($(window).width() - $('#image-viewer-image-wrapper img').width()) / 2
              return
            ), 100
          imageViewerCaption.html(caption).css('opacity', 1).show()
          imageViewerWrapper.panzoom 'reset', false
          setTimeout (->
            imageViewer.css 'background-position-x', -100
            imageViewerImage.show()
            return
          ), 1000
          return
        ), 10
      else
        # trigger analytics
        triggerAnalytics 'gallery/' + $(this).data('id') + '/click'
        # not already zoomed: zoom!
        $('.gallery-item').removeClass 'zoomed'
        $(this).addClass 'zoomed'
      false
    setInterval (->
      masonryGrid.masonry 'layout'
      return
    ), 50
    return
  ###

  # Click the first nav link to begin with
  $("a[href='#{$('body').data('start-slide-id')}'], nav a:first").first().trigger 'click'

  # Finally, mark page as loaded in a short while (after the first fade has completed)
  setTimeout ->
    $('body').removeClass 'not-loaded'
  , 200