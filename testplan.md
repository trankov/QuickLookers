# План тестирования QuickLookers

Таблица всех поддающихся тестированию функций/методов в продуктовом коде
(`Sources/`, `App/`, `PreviewExtension/`). Колонки `edge`/`end2end`/`unit`/`integration`
оставлены пустыми — отмечать по мере покрытия (например `✓` или ссылкой на тест).

| Файл | Тестируемый объект | edge | end2end | unit | integration |
|---|---|---|---|---|---|
| Sources/QuickLookersEngine/EngineFactory.swift | QuickLookersEngineFactory.makeDefault(importedGrammarsDir:importedThemesDir:) | | | | |
| Sources/QuickLookersEngine/EngineResources.swift | QuickLookersEngineResources.grammarsDirectory() | | | | |
| Sources/QuickLookersEngine/EngineResources.swift | QuickLookersEngineResources.themesDirectory() | | | | |
| Sources/QuickLookersEngine/EngineResources.swift | QuickLookersEngineResources.catalogSidecarURLs() | | | | |
| Sources/QuickLookersEngine/JSCoreRuntime.swift | JSCoreRuntime.init(bundleScript:) | | | | |
| Sources/QuickLookersEngine/JSCoreRuntime.swift | JSCoreRuntime.loadBundledScript() | | | | |
| Sources/QuickLookersEngine/JSCoreRuntime.swift | JSCoreRuntime.registerLanguage(json:) | | | | |
| Sources/QuickLookersEngine/JSCoreRuntime.swift | JSCoreRuntime.registerTheme(json:) | | | | |
| Sources/QuickLookersEngine/JSCoreRuntime.swift | JSCoreRuntime.highlight(code:language:theme:) | | | | |
| Sources/QuickLookersEngine/Providers.swift | BundledGrammarProvider.grammarJSON(languageId:) | | | | |
| Sources/QuickLookersEngine/Providers.swift | BundledThemeProvider.themeJSON(themeId:) | | | | |
| Sources/QuickLookersEngine/Providers.swift | CompositeGrammarProvider.grammarJSON(languageId:) | | | | |
| Sources/QuickLookersEngine/Providers.swift | CompositeThemeProvider.themeJSON(themeId:) | | | | |
| Sources/QuickLookersEngine/ShikiEngine.swift | ShikiEngine.highlightToHTML(_:) | | | | |
| Sources/QuickLookersImportKit/GrammarNormalizer.swift | GrammarNormalizer.toJSON(_:path:) | | | | |
| Sources/QuickLookersImportKit/GrammarNormalizer.swift | GrammarNormalizer.normalize(languageId:grammarJSON:embeddedLanguageIds:siblingGrammars:) | | | | |
| Sources/QuickLookersImportKit/ImportID.swift | isSafeImportID(_:) | | | | |
| Sources/QuickLookersImportKit/JSONCParser.swift | JSONCParser.object(from:) | | | | |
| Sources/QuickLookersImportKit/JSONCParser.swift | JSONCParser.toStrictJSON(_:) | | | | |
| Sources/QuickLookersImportKit/ThemeFileLoader.swift | ThemeFileLoader.loadStrictThemeJSON(data:fileExtension:uiTheme:) | | | | |
| Sources/QuickLookersImportKit/ThemeNormalizer.swift | ThemeNormalizer.slug(_:) | | | | |
| Sources/QuickLookersImportKit/ThemeNormalizer.swift | ThemeNormalizer.isDark(uiTheme:) | | | | |
| Sources/QuickLookersImportKit/ThemeNormalizer.swift | ThemeNormalizer.normalize(label:uiTheme:themeJSON:existingSlugs:) | | | | |
| Sources/QuickLookersImportKit/VsixImporter.swift | VsixImporter.callAsFunction(vsixData:) | | | | |
| Sources/QuickLookersImportKit/VsixManifest.swift | VsixManifest.parse(packageJSON:) | | | | |
| Sources/QuickLookersImportKit/ZipReader.swift | ZipReader.entryNames(in:) | | | | |
| Sources/QuickLookersImportKit/ZipReader.swift | ZipReader.entry(_:in:) | | | | |
| Sources/QuickLookersSettingsKit/CatalogSource.swift | FileCatalogSource.loadCatalog() | | | | |
| Sources/QuickLookersSettingsKit/CatalogSource.swift | FileCatalogSource.catalogFromSidecars() | | | | |
| Sources/QuickLookersSettingsKit/CatalogSource.swift | FileCatalogSource.catalogFromDirectories() | | | | |
| Sources/QuickLookersSettingsKit/CatalogSource.swift | FileCatalogSource.jsonFiles(in:) | | | | |
| Sources/QuickLookersSettingsKit/DeclaredTypes.swift | DeclaredTypes.languageId(forPathExtension:) | | | | |
| Sources/QuickLookersSettingsKit/DeclaredTypes.swift | isLanguageEnabled(_:settings:) | | | | |
| Sources/QuickLookersSettingsKit/DeclaredTypes.swift | isPreviewEnabled(_:settings:) | | | | |
| Sources/QuickLookersSettingsKit/DeclaredTypes.swift | previewLanguageId(forPathExtension:settings:) | | | | |
| Sources/QuickLookersSettingsKit/ImportedLibrary.swift | ImportedLibrary.sidecarURLsForCatalog() | | | | |
| Sources/QuickLookersSettingsKit/ImportedLibrary.swift | ImportedLibrary.importedIds() | | | | |
| Sources/QuickLookersSettingsKit/ImportedLibrary.swift | ImportedLibrary.write(_:) | | | | |
| Sources/QuickLookersSettingsKit/ImportedLibrary.swift | ImportedLibrary.remove(kind:id:) | | | | |
| Sources/QuickLookersSettingsKit/ImportedLibrary.swift | ImportedLibrary.loadSidecar() | | | | |
| Sources/QuickLookersSettingsKit/ImportedLibrary.swift | ImportedLibrary.saveSidecar(_:) | | | | |
| Sources/QuickLookersSettingsKit/ManagerSettings.swift | FontSettings.clampSize(_:) | | | | |
| Sources/QuickLookersSettingsKit/SettingsStore.swift | SettingsStore.load() | | | | |
| Sources/QuickLookersSettingsKit/SettingsStore.swift | SettingsStore.save(_:) | | | | |
| Sources/QuickLookersSettingsKit/SettingsStore.swift | resolvedThemeId(activeThemeId:availableThemeIds:) | | | | |
| Sources/QuickLookersSettingsKit/SettingsStore.swift | quickLookersContainerURL() | | | | |
| Sources/QuickLookersEditorKit/EditorScanner.swift | EditorScanner.scan(applicationsDir:) | | | | |
| Sources/QuickLookersEditorKit/EditorSettingsReader.swift | EditorSettingsReader.read(editor:appSupportDir:) | | | | |
| Sources/QuickLookersEditorKit/EditorThemeResolver.swift | EditorThemeResolver.resolve(label:catalog:extensionsDir:) | | | | |
| Sources/QuickLookersPreviewKit/CodeTrim.swift | trimToFirstLines(_:max:) | 🟢 | | 🟢 | 🟢 |
| Sources/QuickLookersPreviewKit/CodeTrim.swift | readBoundedPrefix(of:maxBytes:) | 🟢 | | 🟢 | |
| Sources/QuickLookersPreviewKit/HTMLCache.swift | HTMLCacheKey.init(path:mtime:size:languageId:themeId:fontFamily:fontSize:maxLines:bundleVersion:) | 🟢 | | 🟢 | |
| Sources/QuickLookersPreviewKit/HTMLCache.swift | HTMLCache.lookup(_:) | 🟢 | | 🟢 | 🟢 |
| Sources/QuickLookersPreviewKit/HTMLCache.swift | HTMLCache.store(_:html:) | 🟢 | | 🟢 | 🟢 |
| Sources/QuickLookersPreviewKit/HTMLCache.swift | HTMLCache.evictIfNeeded() | 🟢 | | 🟢 | 🟢 |
| Sources/QuickLookersPreviewKit/PreviewPage.swift | sanitizedFontFamily(_:) | 🟢 | | 🟢 | |
| Sources/QuickLookersPreviewKit/PreviewPage.swift | previewPageHTML(highlighted:fontFamily:fontSize:truncatedNotice:) | 🟢 | | 🟢 | 🟢 |
| App/BookmarkStore.swift | AccessScope.url | | | | |
| App/BookmarkStore.swift | AccessScope.defaultsKey | | | | |
| App/BookmarkStore.swift | AccessScope.prompt | | | | |
| App/BookmarkStore.swift | BookmarkStore.accessURL(for:) | | | | |
| App/BookmarkStore.swift | BookmarkStore.withAccess(_:_:) | | | | |
| App/BookmarkStore.swift | BookmarkStore.resolveBookmark(_:) | | | | |
| App/BookmarkStore.swift | BookmarkStore.requestAccess(_:) | | | | |
| App/CodePreviewView.swift | CodePreviewView.updateNSView(_:context:) | | | | |
| App/FontPanelController.swift | FontPanelController.present(current:onChange:) | | | | |
| App/FontPanelController.swift | FontPanelController.changeFont(_:) | | | | |
| App/FontPanelController.swift | FontPanelController.validModesForFontPanel(_:) | | | | |
| App/FormatsTab.swift | FormatsTab.filteredLanguages | | | | |
| App/ImportModel.swift | ImportModel.runImport() | | | | |
| App/ImportModel.swift | ImportModel.importFile(_:) | | | | |
| App/ImportModel.swift | ImportModel.message(for:) | | | | |
| App/ImportModel.swift | ImportModel.remove(kind:id:) | | | | |
| App/ImportModel.swift | ImportModel.scanEditors(_:) | | | | |
| App/ImportModel.swift | ImportModel.importFromEditor(_:store:catalog:) | | | | |
| App/LivePreview.swift | FragmentCache.fragment(forKey:make:) | | | | |
| App/LivePreview.swift | FragmentCache.invalidate() | | | | |
| App/LivePreview.swift | SettingsModel.previewHTML(languageId:code:) | | | | |
| App/LivePreview.swift | MonospaceFonts.families | | | | |
| App/SettingsModel.swift | SettingsModel.init() | | | | |
| App/SettingsModel.swift | SettingsModel.reloadCatalog() | | | | |
| App/SettingsModel.swift | SettingsModel.loadCatalog() | | | | |
| App/SettingsModel.swift | SettingsModel.makeFileTypeRows(catalog:) | | | | |
| App/SettingsModel.swift | SettingsModel.update(_:) | | | | |
| App/SettingsModel.swift | SettingsModel.isLanguageOn(_:) | | | | |
| App/SettingsModel.swift | SettingsModel.isPreviewOn(_:) | | | | |
| App/SettingsModel.swift | SettingsModel.setLanguageOn(_:_:) | | | | |
| App/SettingsModel.swift | SettingsModel.setPreviewOn(_:_:) | | | | |
| App/SettingsModel.swift | SettingsModel.CatalogLookup.themeId(forDisplayName:) | | | | |
| App/SettingsModel.swift | SettingsModel.applyEditorResult(themeId:font:) | | | | |
| App/ThemesTab.swift | ThemesTab.selectEditor(_:) | | | | |
| PreviewExtension/PreviewViewController.swift | PreviewViewController.makeWebView() | | | | |
| PreviewExtension/PreviewViewController.swift | PreviewViewController.acquireWebView() | | | | |
| PreviewExtension/PreviewViewController.swift | PreviewViewController.releaseWebView(_:) | | | | |
| PreviewExtension/PreviewViewController.swift | PreviewViewController.loadView() | | | | |
| PreviewExtension/PreviewViewController.swift | PreviewViewController.preparePreviewOfFile(at:) | | | | |
| PreviewExtension/PreviewViewController.swift | PreviewViewController.finishLoad(_:) | | | | |
| PreviewExtension/PreviewViewController.swift | PreviewViewController.webView(_:didFinish:) | | | | |
| PreviewExtension/PreviewViewController.swift | PreviewViewController.webView(_:didFail:withError:) | | | | |
| PreviewExtension/PreviewViewController.swift | PreviewViewController.webView(_:didFailProvisionalNavigation:withError:) | | | | |
| PreviewExtension/PreviewViewController.swift | PreviewViewController.settings() | | | | |
| PreviewExtension/PreviewViewController.swift | PreviewViewController.themeIds() | | | | |
| PreviewExtension/PreviewViewController.swift | PreviewViewController.engine() | | | | |
