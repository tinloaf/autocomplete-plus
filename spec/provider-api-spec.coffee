{waitForAutocomplete, triggerAutocompletion} = require './spec-helper'
_ = require 'underscore-plus'

describe 'Provider API', ->
  [completionDelay, editor, mainModule, autocompleteManager, registration, testProvider] = []

  beforeEach ->
    runs ->
      # Set to live completion
      atom.config.set('autocomplete-plus.enableAutoActivation', true)
      atom.config.set('editor.fontSize', '16')

      # Set the completion delay
      completionDelay = 100
      atom.config.set('autocomplete-plus.autoActivationDelay', completionDelay)
      completionDelay += 100 # Rendering

      workspaceElement = atom.views.getView(atom.workspace)
      jasmine.attachToDOM(workspaceElement)

    # Activate the package
    waitsForPromise ->
      Promise.all [
        atom.packages.activatePackage('language-javascript')
        atom.workspace.open('sample.js').then (e) -> editor = e
        atom.packages.activatePackage('autocomplete-plus').then (a) ->
          mainModule = a.mainModule
          autocompleteManager = mainModule.autocompleteManager
      ]

  afterEach ->
    registration?.dispose() if registration?.dispose?
    registration = null
    testProvider?.dispose() if testProvider?.dispose?
    testProvider = null

  describe 'Provider API v2.0.0', ->
    it 'registers the provider specified by [provider]', ->
      testProvider =
        selector: '.source.js,.source.coffee'
        getSuggestions: (options) -> [text: 'ohai', replacementPrefix: 'ohai']

      expect(_.size(autocompleteManager.providerManager.providersForScopeDescriptor('.source.js'))).toEqual(1)
      registration = atom.packages.serviceHub.provide('autocomplete.provider', '2.0.0', [testProvider])
      expect(_.size(autocompleteManager.providerManager.providersForScopeDescriptor('.source.js'))).toEqual(2)

    it 'registers the provider specified by the naked provider', ->
      testProvider =
        selector: '.source.js,.source.coffee'
        getSuggestions: (options) -> [text: 'ohai', replacementPrefix: 'ohai']

      expect(_.size(autocompleteManager.providerManager.providersForScopeDescriptor('.source.js'))).toEqual(1)
      registration = atom.packages.serviceHub.provide('autocomplete.provider', '2.0.0', testProvider)
      expect(_.size(autocompleteManager.providerManager.providersForScopeDescriptor('.source.js'))).toEqual(2)

    it 'passes the correct parameters to getSuggestions for the version', ->
      testProvider =
        selector: '.source.js,.source.coffee'
        getSuggestions: (options) -> [text: 'ohai', replacementPrefix: 'ohai']

      registration = atom.packages.serviceHub.provide('autocomplete.provider', '2.0.0', testProvider)

      spyOn(testProvider, 'getSuggestions')
      triggerAutocompletion(editor, true, 'o')

      runs ->
        args = testProvider.getSuggestions.mostRecentCall.args[0]
        expect(args.editor).toBeDefined()
        expect(args.bufferPosition).toBeDefined()
        expect(args.scopeDescriptor).toBeDefined()
        expect(args.prefix).toBeDefined()

        expect(args.scope).not.toBeDefined()
        expect(args.scopeChain).not.toBeDefined()
        expect(args.buffer).not.toBeDefined()
        expect(args.cursor).not.toBeDefined()

    it 'correctly displays the suggestion options', ->
      testProvider =
        selector: '.source.js, .source.coffee'
        getSuggestions: (options) ->
          [
            text: 'ohai',
            replacementPrefix: 'o',
            rightLabelHTML: '<span style="color: red">ohai</span>',
            description: 'There be documentation'
          ]
      registration = atom.packages.serviceHub.provide('autocomplete.provider', '2.0.0', testProvider)

      triggerAutocompletion(editor, true, 'o')

      runs ->
        suggestionListView = atom.views.getView(autocompleteManager.suggestionList)
        expect(suggestionListView.querySelector('li .right-label')).toHaveHtml('<span style="color: red">ohai</span>')
        expect(suggestionListView.querySelector('.word')).toHaveText('ohai')
        expect(suggestionListView.querySelector('.suggestion-description-content')).toHaveText('There be documentation')
        expect(suggestionListView.querySelector('.suggestion-description-more-link').style.display).toBe 'none'

    it "favors the `displayText` over text or snippet suggestion options", ->
      testProvider =
        selector: '.source.js, .source.coffee'
        getSuggestions: (options) ->
          [
            text: 'ohai',
            snippet: 'snippet'
            displayText: 'displayOHAI'
            replacementPrefix: 'o',
            rightLabelHTML: '<span style="color: red">ohai</span>',
            description: 'There be documentation'
          ]
      registration = atom.packages.serviceHub.provide('autocomplete.provider', '2.0.0', testProvider)

      triggerAutocompletion(editor, true, 'o')

      runs ->
        suggestionListView = atom.views.getView(autocompleteManager.suggestionList)
        expect(suggestionListView.querySelector('.word')).toHaveText('displayOHAI')

    it 'correctly displays the suggestion description and More link', ->
      testProvider =
        selector: '.source.js, .source.coffee'
        getSuggestions: (options) ->
          [
            text: 'ohai',
            replacementPrefix: 'o',
            rightLabelHTML: '<span style="color: red">ohai</span>',
            description: 'There be documentation'
            descriptionMoreURL: 'http://google.com'
          ]
      registration = atom.packages.serviceHub.provide('autocomplete.provider', '2.0.0', testProvider)

      triggerAutocompletion(editor, true, 'o')

      runs ->
        suggestionListView = atom.views.getView(autocompleteManager.suggestionList)
        content = suggestionListView.querySelector('.suggestion-description-content')
        moreLink = suggestionListView.querySelector('.suggestion-description-more-link')
        expect(content).toHaveText('There be documentation')
        expect(moreLink).toHaveText('More..')
        expect(moreLink.style.display).toBe 'inline'
        expect(moreLink.getAttribute('href')).toBe 'http://google.com'
