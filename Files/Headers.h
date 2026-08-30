// Perferences and headers
// For Tweak.x
#import <YouTubeHeader/_ASDisplayView.h>
#import <YouTubeHeader/YTIIcon.h>
#import <YouTubeHeader/YTRightNavigationButtons.h>
#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTPlayerBarController.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/YTWatchController.h>
#import <YouTubeHeader/YTIMenuConditionalServiceItemRenderer.h>
#import <YouTubeHeader/YTIPivotBarRenderer.h>
#import <YouTubeHeader/YTPivotBarItemView.h>
#import <YouTubeHeader/YTActionSheetAction.h>
#import <YouTubeHeader/YTIMenuItemSupportedRenderers.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTVideoQualitySwitchOriginalController.h>
#import <YouTubeHeader/YTVideoQualitySwitchRedesignedController.h>
#import <YouTubeHeader/YTInnerTubeCollectionViewController.h>
#import <YouTubeHeader/YTIShowFullscreenInterstitialCommand.h>
#import <YouTubeHeader/YTISectionListRenderer.h>
#import <YouTubeHeader/YTIShelfRenderer.h>
#import <YouTubeHeader/YTIWatchNextResponse.h>
#import <YouTubeHeader/YTPlayerOverlay.h>
#import <YouTubeHeader/YTPlayerOverlayProvider.h>
#import <YouTubeHeader/YTReelModel.h>
#import <YouTubeHeader/YTAlertView.h>
#import <YouTubeHeader/YTVarispeedSwitchController.h>
#import <YouTubeHeader/YTVarispeedSwitchControllerOption.h>
#import <YouTubeHeader/YTInlinePlayerBarContainerView.h>
#import <YouTubeHeader/YTSingleVideoTime.h>
#import <YouTubeHeader/YTSingleVideoController.h>
#import <YouTubeHeader/YTPlayerView.h>
#import <YouTubeHeader/YTShortsPlayerViewController.h>
#import <YouTubeHeader/YTReelPlayerViewController.h>
#import <YouTubeHeader/YTLabel.h>
#import <YouTubeHeader/MLFormat.h>
#import <YouTubeHeader/MLQuickMenuVideoQualitySettingFormatConstraint.h>
#import <YouTubeHeader/YTCommonColorPalette.h>
#import <YouTubeHeader/YTIPivotBarSupportedRenderers.h>
#import <YouTubeHeader/YTIBrowseRequest.h>
#import <YouTubeHeader/YTAssetLoader.h>
#import <MediaPlayer/MediaPlayer.h>
#import <YouTubeHeader/ASCollectionView.h>
#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/YTTypeStyle.h>
#import <YouTubeHeader/YTModularPlayerBarController.h>
#import <dlfcn.h>
#import <jbroot.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#import <YouTubeHeader/YTAppViewControllerImpl.h>
#import <YouTubeHeader/YTAppViewController.h>
#import <YouTubeHeader/YTDefaultSheetController.h>
#import <YouTubeHeader/YTIFormatStream.h>
#import <YouTubeHeader/YTIPlayerResponse.h>
#import <YouTubeHeader/YTPlayerResponse.h>
#import <YouTubeHeader/YTIVideoDetails.h>
#import <YouTubeHeader/YTIStreamingData.h>
#import <YouTubeHeader/YTIFormattedString.h>
#import <YouTubeHeader/GOOHUDManagerInternal.h>
#import <YouTubeHeader/MLInnerTubeCaptionTrack.h>
#import <YouTubeHeader/MLCaption.h>
#import <YouTubeHeader/MLFormat3Captions.h>
#import <YouTubeHeader/YTFormat3CaptionViewController.h>
#import <YouTubeHeader/YTWatchNextResultsViewController.h>
#import <YouTubeHeader/YTIThumbnailDetails.h>
#import <YouTubeHeader/YTIThumbnailDetails_Thumbnail.h>
#import <YouTubeHeader/_ASCollectionViewCell.h>
#import <YouTubeHeader/YTReelElementAsyncComponentView.h>

#import <YouTubeHeader/ASCellNode.h>
#import <YouTubeHeader/ASCollectionElement.h>
#import <YouTubeHeader/ASCollectionNode.h>
#import <YouTubeHeader/ASControlNode.h>
#import <YouTubeHeader/ASDimension.h>
#import <YouTubeHeader/ASDisplayNode.h>
#import <YouTubeHeader/ASEditableTextNode.h>
#import <YouTubeHeader/ASImageNodeDrawParameters.h>
#import <YouTubeHeader/ASLayoutElementStyleYoga.h>
#import <YouTubeHeader/ASNodeContext.h>
#import <YouTubeHeader/ASNodeController.h>
#import <YouTubeHeader/ASTextNode.h>
#import <YouTubeHeader/Debug.h>
#import <YouTubeHeader/ELMCellNode.h>
#import <YouTubeHeader/ELMCollectionNode.h>
#import <YouTubeHeader/ELMComponent.h>
#import <YouTubeHeader/ELMContainerNode.h>
#import <YouTubeHeader/ELMController.h>
#import <YouTubeHeader/ELMElement.h>
#import <YouTubeHeader/ELMNodeController.h>
#import <YouTubeHeader/ELMNodeFactory.h>
#import <YouTubeHeader/ELMPBElement.h>
#import <YouTubeHeader/ELMPBIdentifierProperties.h>
#import <YouTubeHeader/ELMPBProperties.h>
#import <YouTubeHeader/ELMPBShowActionSheetCommand.h>
#import <YouTubeHeader/ELMPBType.h>
#import <YouTubeHeader/ELMPBUpdateActionSheetCommand.h>
#import <YouTubeHeader/ELMTextNode.h>
#import <YouTubeHeader/ELMTouchCommandPropertiesHandler.h>
#import <YouTubeHeader/ELMView.h>
#import <YouTubeHeader/GCKNNetworkReachability.h>
#import <YouTubeHeader/GIMBindingBuilder.h>
#import <YouTubeHeader/GIMMe.h>
#import <YouTubeHeader/GOOAlertView.h>
#import <YouTubeHeader/GOODialogView.h>
#import <YouTubeHeader/GOODialogViewAction.h>
#import <YouTubeHeader/GOOHUDMessage.h>
#import <YouTubeHeader/GOOHeaderViewController.h>
#import <YouTubeHeader/GOOModalView.h>
#import <YouTubeHeader/GOOMultiLineView.h>
#import <YouTubeHeader/GPBDescriptor.h>
#import <YouTubeHeader/GPBExtensionDescriptor.h>
#import <YouTubeHeader/GPBExtensionRegistry.h>
#import <YouTubeHeader/GPBMessage.h>
#import <YouTubeHeader/GPBRootObject.h>
#import <YouTubeHeader/GPBUInt64Array.h>
#import <YouTubeHeader/GPBUnknownField.h>
#import <YouTubeHeader/GPBUnknownFieldSet.h>
#import <YouTubeHeader/GPBUnknownFields.h>
#import <YouTubeHeader/HAMAsyncVTVideoDecoder.h>
#import <YouTubeHeader/HAMBaseComponent.h>
#import <YouTubeHeader/HAMBuildableObject.h>
#import <YouTubeHeader/HAMChunk.h>
#import <YouTubeHeader/HAMDefaultABRPolicy.h>
#import <YouTubeHeader/HAMDefaultABRPolicyConfig.h>
#import <YouTubeHeader/HAMEvent.h>
#import <YouTubeHeader/HAMFormat.h>
#import <YouTubeHeader/HAMFormatDescription.h>
#import <YouTubeHeader/HAMFormatSelection.h>
#import <YouTubeHeader/HAMFormatSelectionEvent.h>
#import <YouTubeHeader/HAMInputSampleBuffer.h>
#import <YouTubeHeader/HAMMIMEType.h>
#import <YouTubeHeader/HAMMediaChunk.h>
#import <YouTubeHeader/HAMPixelBufferPool.h>
#import <YouTubeHeader/HAMPixelBufferRenderingView.h>
#import <YouTubeHeader/HAMPlayer.h>
#import <YouTubeHeader/HAMPlayerRenderViewType.h>
#import <YouTubeHeader/HAMSBDLSampleBufferRenderingView.h>
#import <YouTubeHeader/HAMSampleBuffer.h>
#import <YouTubeHeader/HAMSampleBufferDisplayLayerView.h>
#import <YouTubeHeader/HAMSoftwareStreamFilter.h>
#import <YouTubeHeader/HAMVPXVideoDecoder.h>
#import <YouTubeHeader/HAMVideoDecoderDelegate.h>
#import <YouTubeHeader/HAMVideoDecoderSampleBufferSource.h>
#import <YouTubeHeader/ICNClientFile.h>
#import <YouTubeHeader/ICNClientFileGroup.h>
#import <YouTubeHeader/MDCButton.h>
#import <YouTubeHeader/MDCSlider.h>
#import <YouTubeHeader/MDCTextField.h>
#import <YouTubeHeader/MDXScreenDiscoveryManager.h>
#import <YouTubeHeader/MDXSessionManager.h>
#import <YouTubeHeader/MLABRPolicy.h>
#import <YouTubeHeader/MLABRPolicyFormatData.h>
#import <YouTubeHeader/MLABRPolicyNew.h>
#import <YouTubeHeader/MLABRPolicyOld.h>
#import <YouTubeHeader/MLAVAssetPlayer.h>
#import <YouTubeHeader/MLAVAssetPlayerDelegate.h>
#import <YouTubeHeader/MLAVPIPPlayerLayerView.h>
#import <YouTubeHeader/MLAVPlayer.h>
#import <YouTubeHeader/MLAVPlayerLayerView.h>
#import <YouTubeHeader/MLAVPlayerViewDelegate.h>
#import <YouTubeHeader/MLCaptionSegment.h>
#import <YouTubeHeader/MLDefaultPlayerViewFactory.h>
#import <YouTubeHeader/MLHAMPlayer.h>
#import <YouTubeHeader/MLHAMPlayerItem.h>
#import <YouTubeHeader/MLHAMPlayerItemSegment.h>
#import <YouTubeHeader/MLHAMPlayerViewProtocol.h>
#import <YouTubeHeader/MLHAMQueuePlayer.h>
#import <YouTubeHeader/MLHAMSBDLSampleBufferRenderingView.h>
#import <YouTubeHeader/MLHLSMasterPlaylist.h>
#import <YouTubeHeader/MLHLSRemotePlaylist.h>
#import <YouTubeHeader/MLHLSStreamSelector.h>
#import <YouTubeHeader/MLInnerTubeCaptionController.h>
#import <YouTubeHeader/MLInnerTubePlayerConfig.h>
#import <YouTubeHeader/MLOnesieVideoData.h>
#import <YouTubeHeader/MLPIPController.h>
#import <YouTubeHeader/MLPIPControllerImpl.h>
#import <YouTubeHeader/MLPlatypusABRLoader.h>
#import <YouTubeHeader/MLPlayerDelegate.h>
#import <YouTubeHeader/MLPlayerEventCenter.h>
#import <YouTubeHeader/MLPlayerPool.h>
#import <YouTubeHeader/MLPlayerPoolImpl.h>
#import <YouTubeHeader/MLPlayerReloadContext.h>
#import <YouTubeHeader/MLPlayerStickySettings.h>
#import <YouTubeHeader/MLPlayerViewProtocol.h>
#import <YouTubeHeader/MLQOEPingController.h>
#import <YouTubeHeader/MLQueuePlayerDelegate.h>
#import <YouTubeHeader/MLRemoteStream.h>
#import <YouTubeHeader/MLServerABRFormatAssociatedData.h>
#import <YouTubeHeader/MLStreamSelector.h>
#import <YouTubeHeader/MLStreamSelectorDelegate.h>
#import <YouTubeHeader/MLStreamingData.h>
#import <YouTubeHeader/MLVideo.h>
#import <YouTubeHeader/MLVideoDecoderFactory.h>
#import <YouTubeHeader/MLVideoFormatConstraint.h>
#import <YouTubeHeader/NSArray+YouTube.h>
#import <YouTubeHeader/QTMIcon.h>
#import <YouTubeHeader/SRLRegistry.h>
#import <YouTubeHeader/UIColor+YouTube.h>
#import <YouTubeHeader/UIDevice+YouTube.h>
#import <YouTubeHeader/UIImage+YouTube.h>
#import <YouTubeHeader/UIView+AsyncDisplayKit.h>
#import <YouTubeHeader/UIView+YouTube.h>
#import <YouTubeHeader/YTAccountScopedInnerTubeContextFactory.h>
#import <YouTubeHeader/YTActionSheetController.h>
#import <YouTubeHeader/YTActionSheetDialogViewController.h>
#import <YouTubeHeader/YTActionSheetDialogViewControllerDelegate.h>
#import <YouTubeHeader/YTAdjustableAccessibilityProtocol.h>
#import <YouTubeHeader/YTAppCollectionViewController.h>
#import <YouTubeHeader/YTAppSettingsSectionItemActionController.h>
#import <YouTubeHeader/YTAppSettingsStore.h>
#import <YouTubeHeader/YTApplicationNotificationsObserver.h>
#import <YouTubeHeader/YTAsyncCollectionView.h>
#import <YouTubeHeader/YTAttributedLabel.h>
#import <YouTubeHeader/YTAttributedLabelFactory.h>
#import <YouTubeHeader/YTAutonavEndscreenController.h>
#import <YouTubeHeader/YTAutoplayController.h>
#import <YouTubeHeader/YTBackgroundabilityPolicy.h>
#import <YouTubeHeader/YTBackgroundabilityPolicyImpl.h>
#import <YouTubeHeader/YTBaseFeedController.h>
#import <YouTubeHeader/YTBaseInnerTubeViewController.h>
#import <YouTubeHeader/YTCaptionViewController.h>
#import <YouTubeHeader/YTCellController.h>
#import <YouTubeHeader/YTCoWatchWatchEndpointWrapperCommandHandler.h>
#import <YouTubeHeader/YTColdConfig.h>
#import <YouTubeHeader/YTCollectionViewCell.h>
#import <YouTubeHeader/YTCollectionViewCellProtocol.h>
#import <YouTubeHeader/YTCollectionViewController.h>
#import <YouTubeHeader/YTColorPalette.h>
#import <YouTubeHeader/YTCommandResponderEvent.h>
#import <YouTubeHeader/YTCommonButton.h>
#import <YouTubeHeader/YTCommonUtils.h>
#import <YouTubeHeader/YTContentVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTDefaultTypeStyle.h>
#import <YouTubeHeader/YTELMContext.h>
#import <YouTubeHeader/YTELMView.h>
#import <YouTubeHeader/YTEditResources.h>
#import <YouTubeHeader/YTElementsCellController.h>
#import <YouTubeHeader/YTEngagementPanelContainerViewController.h>
#import <YouTubeHeader/YTFeedSectionController.h>
#import <YouTubeHeader/YTFontAttributes.h>
#import <YouTubeHeader/YTFrostedGlassView.h>
#import <YouTubeHeader/YTFullscreenEngagementActionBarButtonRenderer.h>
#import <YouTubeHeader/YTFullscreenEngagementActionBarButtonView.h>
#import <YouTubeHeader/YTGlassContainerView.h>
#import <YouTubeHeader/YTGlobalConfig.h>
#import <YouTubeHeader/YTGridBaseView.h>
#import <YouTubeHeader/YTGridVideoNode.h>
#import <YouTubeHeader/YTGridVideoView.h>
#import <YouTubeHeader/YTHUDMessage.h>
#import <YouTubeHeader/YTHUDSnackbarMessage.h>
#import <YouTubeHeader/YTHeaderContentComboViewController.h>
#import <YouTubeHeader/YTHeaderViewController.h>
#import <YouTubeHeader/YTHotConfig.h>
#import <YouTubeHeader/YTIAccessibilityData.h>
#import <YouTubeHeader/YTIAccessibilitySupportedDatas.h>
#import <YouTubeHeader/YTIAdLoggingDataContainer.h>
#import <YouTubeHeader/YTIAdSlotLoggingData.h>
#import <YouTubeHeader/YTIAppDeepLinkEndpoint.h>
#import <YouTubeHeader/YTIAppDeepLinkEndpointRoot.h>
#import <YouTubeHeader/YTIAudioTrack.h>
#import <YouTubeHeader/YTIBrowseEndpoint.h>
#import <YouTubeHeader/YTIButtonRenderer.h>
#import <YouTubeHeader/YTIButtonSupportedRenderers.h>
#import <YouTubeHeader/YTIChapterRenderer.h>
#import <YouTubeHeader/YTIClientInfo.h>
#import <YouTubeHeader/YTICoWatchWatchEndpointWrapperCommand.h>
#import <YouTubeHeader/YTICoWatchWatchEndpointWrapperCommandRoot.h>
#import <YouTubeHeader/YTIColorInfo.h>
#import <YouTubeHeader/YTICommand.h>
#import <YouTubeHeader/YTICommandExecutorCommand.h>
#import <YouTubeHeader/YTICompactLinkRenderer.h>
#import <YouTubeHeader/YTICompactVideoRenderer.h>
#import <YouTubeHeader/YTIElementLoggingContainer.h>
#import <YouTubeHeader/YTIElementRendererCompatibilityOptions.h>
#import <YouTubeHeader/YTIEmbeddedFileGroupSchema.h>
#import <YouTubeHeader/YTIEngagementPanelIdentifier.h>
#import <YouTubeHeader/YTIFormattedStringLabel.h>
#import <YouTubeHeader/YTIFormattedStringSupportedAccessibilityDatas.h>
#import <YouTubeHeader/YTIGuideResponse.h>
#import <YouTubeHeader/YTIGuideResponseSupportedRenderers.h>
#import <YouTubeHeader/YTIHamplayerABRConfig.h>
#import <YouTubeHeader/YTIHamplayerConfig.h>
#import <YouTubeHeader/YTIHamplayerHotConfig.h>
#import <YouTubeHeader/YTIHamplayerSABRAudioTrackRendererConfig.h>
#import <YouTubeHeader/YTIHamplayerSoftwareStreamFilter.h>
#import <YouTubeHeader/YTIHamplayerStreamFilter.h>
#import <YouTubeHeader/YTIHorizontalListRenderer.h>
#import <YouTubeHeader/YTIHorizontalListSupportedRenderers.h>
#import <YouTubeHeader/YTIHotConfigGroup.h>
#import <YouTubeHeader/YTIInlinePlaybackRenderer.h>
#import <YouTubeHeader/YTIInnerTubeContext.h>
#import <YouTubeHeader/YTIIosMediaHotConfig.h>
#import <YouTubeHeader/YTIIosOnesieHotConfig.h>
#import <YouTubeHeader/YTIIosSystemShareEndpoint.h>
#import <YouTubeHeader/YTIIosSystemShareEndpointRoot.h>
#import <YouTubeHeader/YTIItemSectionRenderer.h>
#import <YouTubeHeader/YTIItemSectionSupportedRenderers.h>
#import <YouTubeHeader/YTILikeButtonRenderer.h>
#import <YouTubeHeader/YTILikeButtonSupportedRenderers.h>
#import <YouTubeHeader/YTILikeTarget.h>
#import <YouTubeHeader/YTILoggingURLRoot.h>
#import <YouTubeHeader/YTIMediaCommonConfig.h>
#import <YouTubeHeader/YTIMediaHotConfig.h>
#import <YouTubeHeader/YTIMediaQualitySettingsHotConfig.h>
#import <YouTubeHeader/YTIMenuItemSupportedRenderersElementRendererCompatibilityOptionsExtension.h>
#import <YouTubeHeader/YTIMenuNavigationItemRenderer.h>
#import <YouTubeHeader/YTIMenuRenderer.h>
#import <YouTubeHeader/YTIMenuRendererRoot.h>
#import <YouTubeHeader/YTIMenuServiceItemRenderer.h>
#import <YouTubeHeader/YTIMenuSupportedRenderers.h>
#import <YouTubeHeader/YTIModalClientThrottlingRules.h>
#import <YouTubeHeader/YTIModularPlayerBarModel.h>
#import <YouTubeHeader/YTINavigationEndpointInteractionLoggingExtension.h>
#import <YouTubeHeader/YTIOfflinePromoRenderer.h>
#import <YouTubeHeader/YTIOfflineabilityRenderer.h>
#import <YouTubeHeader/YTIOfflineabilitySupportedRenderers.h>
#import <YouTubeHeader/YTIOnesieHotConfig.h>
#import <YouTubeHeader/YTIOpenElementsScreenCommand.h>
#import <YouTubeHeader/YTIPanelContentRenderer.h>
#import <YouTubeHeader/YTIPaygatedQualityDetails.h>
#import <YouTubeHeader/YTIPictureInPictureRendererRoot.h>
#import <YouTubeHeader/YTIPivotBarIconOnlyItemRenderer.h>
#import <YouTubeHeader/YTIPivotBarItemRenderer.h>
#import <YouTubeHeader/YTIPlayerBarDecorationModel.h>
#import <YouTubeHeader/YTIPlayerBarDecorationStyle.h>
#import <YouTubeHeader/YTIPlayerBarGradientColor.h>
#import <YouTubeHeader/YTIPlayerBarPlayingState.h>
#import <YouTubeHeader/YTIPlayerRequest.h>
#import <YouTubeHeader/YTIPlaylistPanelRenderer.h>
#import <YouTubeHeader/YTIPlaylistPanelRenderer_PlaylistPanelVideoSupportedRenderers.h>
#import <YouTubeHeader/YTIPlaylistPanelVideoRenderer.h>
#import <YouTubeHeader/YTIPlaylistVideoListRenderer.h>
#import <YouTubeHeader/YTIPlaylistVideoListSupportedRenderers.h>
#import <YouTubeHeader/YTIPlaylistVideoRenderer.h>
#import <YouTubeHeader/YTIReelItemWatchResponse.h>
#import <YouTubeHeader/YTIReelPlayerHeaderRenderer.h>
#import <YouTubeHeader/YTIReelPlayerHeaderSupportedRenderers.h>
#import <YouTubeHeader/YTIReelPlayerOverlayRenderer.h>
#import <YouTubeHeader/YTIReelWatchEndpoint.h>
#import <YouTubeHeader/YTIRenderer.h>
#import <YouTubeHeader/YTISearchEndpoint.h>
#import <YouTubeHeader/YTISectionListSupportedRenderers.h>
#import <YouTubeHeader/YTIShareVideoEndpoint.h>
#import <YouTubeHeader/YTIShelfSupportedRenderers.h>
#import <YouTubeHeader/YTIShowEngagementPanelEndpoint.h>
#import <YouTubeHeader/YTISlimMetadataButtonRenderer.h>
#import <YouTubeHeader/YTISlimMetadataButtonSupportedRenderers.h>
#import <YouTubeHeader/YTISlimMetadataToggleButtonRenderer.h>
#import <YouTubeHeader/YTISlimVideoScrollableActionBarRenderer.h>
#import <YouTubeHeader/YTISlotData.h>
#import <YouTubeHeader/YTIStringRun.h>
#import <YouTubeHeader/YTIToggleButtonRenderer.h>
#import <YouTubeHeader/YTIUrlEndpoint.h>
#import <YouTubeHeader/YTIVideoQualityPickerEndpoint.h>
#import <YouTubeHeader/YTIWatchEndpoint.h>
#import <YouTubeHeader/YTIcon.h>
#import <YouTubeHeader/YTImageView.h>
#import <YouTubeHeader/YTInlineMutedPlaybackScrubberView.h>
#import <YouTubeHeader/YTInlineMutedPlaybackScrubbingSlider.h>
#import <YouTubeHeader/YTInlinePlayerBarView.h>
#import <YouTubeHeader/YTInnerTubeCellController.h>
#import <YouTubeHeader/YTInnerTubeContextFactory.h>
#import <YouTubeHeader/YTInnerTubeSectionController.h>
#import <YouTubeHeader/YTInterval.h>
#import <YouTubeHeader/YTIntervalNode.h>
#import <YouTubeHeader/YTIntervalTree.h>
#import <YouTubeHeader/YTLightweightQTMButton.h>
#import <YouTubeHeader/YTLikeStatus.h>
#import <YouTubeHeader/YTLiveWatchPlaybackOverlayView.h>
#import <YouTubeHeader/YTLocalPlaybackController.h>
#import <YouTubeHeader/YTMainAppEngagementPanelViewController.h>
#import <YouTubeHeader/YTMainAppPlayerOverlayView.h>
#import <YouTubeHeader/YTMainWindow.h>
#import <YouTubeHeader/YTModularPlayerBarView.h>
#import <YouTubeHeader/YTModuleEngagementPanelViewController.h>
#import <YouTubeHeader/YTMultiSizeViewController.h>
#import <YouTubeHeader/YTNGWatchController.h>
#import <YouTubeHeader/YTNGWatchLayerViewController.h>
#import <YouTubeHeader/YTNGWatchMiniBarView.h>
#import <YouTubeHeader/YTNewFormattedLabel.h>
#import <YouTubeHeader/YTNewLabel.h>
#import <YouTubeHeader/YTNonCriticalStartupTelemetricSmartScheduler.h>
#import <YouTubeHeader/YTOfflineButtonPressedResponderEvent.h>
#import <YouTubeHeader/YTOfflineCapableVideoCellController.h>
#import <YouTubeHeader/YTPageStyleController.h>
#import <YouTubeHeader/YTPageStyleControllerImpl.h>
#import <YouTubeHeader/YTPageStyling.h>
#import <YouTubeHeader/YTPlainLabel.h>
#import <YouTubeHeader/YTPlaybackController.h>
#import <YouTubeHeader/YTPlaybackControllerUIWrapper.h>
#import <YouTubeHeader/YTPlaybackData.h>
#import <YouTubeHeader/YTPlaybackStrippedWatchController.h>
#import <YouTubeHeader/YTPlayerBarProgressDecorationView.h>
#import <YouTubeHeader/YTPlayerBarProtocol.h>
#import <YouTubeHeader/YTPlayerBarRectangleDecorationView.h>
#import <YouTubeHeader/YTPlayerBarScrubberDotDecorationController.h>
#import <YouTubeHeader/YTPlayerBarScrubberDotDecorationView.h>
#import <YouTubeHeader/YTPlayerBarSegmentMarkerView.h>
#import <YouTubeHeader/YTPlayerBarSegmentView.h>
#import <YouTubeHeader/YTPlayerBarSegmentedProgressView.h>
#import <YouTubeHeader/YTPlayerOverlayManager.h>
#import <YouTubeHeader/YTPlayerPIPController.h>
#import <YouTubeHeader/YTPlayerResources.h>
#import <YouTubeHeader/YTPlayerScrubberProtocol.h>
#import <YouTubeHeader/YTPlayerStatus.h>
#import <YouTubeHeader/YTPlayerTapToRetryResponderEvent.h>
#import <YouTubeHeader/YTPlayerViewControllerConfig.h>
#import <YouTubeHeader/YTPlayerViewControllerUIDelegate.h>
#import <YouTubeHeader/YTPlaylistPanelProminentThumbnailVideoCell.h>
#import <YouTubeHeader/YTPlaylistPanelProminentThumbnailVideoCellController.h>
#import <YouTubeHeader/YTPlaylistPanelSectionController.h>
#import <YouTubeHeader/YTPlaylistVideoCellController.h>
#import <YouTubeHeader/YTPlaylistVideoListSectionController.h>
#import <YouTubeHeader/YTQTMButton.h>
#import <YouTubeHeader/YTReelContentModel.h>
#import <YouTubeHeader/YTReelContentView.h>
#import <YouTubeHeader/YTReelDataSource.h>
#import <YouTubeHeader/YTReelLikeModel.h>
#import <YouTubeHeader/YTReelPlayerBottomButton.h>
#import <YouTubeHeader/YTReelPlayerViewControllerSub.h>
#import <YouTubeHeader/YTReelWatchLikesController.h>
#import <YouTubeHeader/YTRendererForOfflineVideo.h>
#import <YouTubeHeader/YTResponder.h>
#import <YouTubeHeader/YTResponderEvent.h>
#import <YouTubeHeader/YTRollingDigit.h>
#import <YouTubeHeader/YTRollingDigitView.h>
#import <YouTubeHeader/YTRollingNumberNode.h>
#import <YouTubeHeader/YTRollingNumberView.h>
#import <YouTubeHeader/YTSafeModeController.h>
#import <YouTubeHeader/YTSearchableSettingsViewController.h>
#import <YouTubeHeader/YTSectionController.h>
#import <YouTubeHeader/YTSectionListGhostCardCell.h>
#import <YouTubeHeader/YTSectionListGhostCardVideoWithContextCell.h>
#import <YouTubeHeader/YTSectionListViewController.h>
#import <YouTubeHeader/YTSegmentableInlinePlayerBarView.h>
#import <YouTubeHeader/YTServiceSectionController.h>
#import <YouTubeHeader/YTSettingsCell.h>
#import <YouTubeHeader/YTSettingsGroupData.h>
#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsSectionController.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTSingleVideo.h>
#import <YouTubeHeader/YTSingleVideoControllerDelegate.h>
#import <YouTubeHeader/YTSingleVideoSequencer.h>
#import <YouTubeHeader/YTSlideForActionsView.h>
#import <YouTubeHeader/YTSlimVideoDetailsActionView.h>
#import <YouTubeHeader/YTSlimVideoDetailsActionViewDelegate.h>
#import <YouTubeHeader/YTSlimVideoDetailsActionsView.h>
#import <YouTubeHeader/YTSlimVideoMetadataExpandingBehavior.h>
#import <YouTubeHeader/YTSlimVideoScrollableActionBarCell.h>
#import <YouTubeHeader/YTSlimVideoScrollableActionBarCellController.h>
#import <YouTubeHeader/YTSlimVideoScrollableActionBarCellControllerDelegate.h>
#import <YouTubeHeader/YTSlimVideoScrollableDetailsActionsProtocol.h>
#import <YouTubeHeader/YTSlimVideoScrollableDetailsActionsView.h>
#import <YouTubeHeader/YTStyledViewController.h>
#import <YouTubeHeader/YTSystemNotifications.h>
#import <YouTubeHeader/YTSystemNotificationsObserver.h>
#import <YouTubeHeader/YTToastResponderEvent.h>
#import <YouTubeHeader/YTTouchFeedbackController.h>
#import <YouTubeHeader/YTTouchFeedbackView.h>
#import <YouTubeHeader/YTUIResources.h>
#import <YouTubeHeader/YTUIUtils.h>
#import <YouTubeHeader/YTVRCaptionOverlayViewController.h>
#import <YouTubeHeader/YTVarispeedSwitchControllerDelegate.h>
#import <YouTubeHeader/YTVarispeedSwitchControllerImpl.h>
#import <YouTubeHeader/YTVersionUtils.h>
#import <YouTubeHeader/YTVideoCellController.h>
#import <YouTubeHeader/YTVideoElementCellController.h>
#import <YouTubeHeader/YTVideoNode.h>
#import <YouTubeHeader/YTVideoPlayerOverlayDelegate.h>
#import <YouTubeHeader/YTVideoWithContextNode.h>
#import <YouTubeHeader/YTWatchLayerViewController.h>
#import <YouTubeHeader/YTWatchMetadataPanelStateResponderProvider.h>
#import <YouTubeHeader/YTWatchMiniBarViewController.h>
#import <YouTubeHeader/YTWatchPlaybackController.h>
#import <YouTubeHeader/YTWatchPlayerViewLayoutSource.h>
#import <YouTubeHeader/YTWatchPullToFullController.h>
#import <YouTubeHeader/YTWatchTransition.h>
#import <YouTubeHeader/YTWatchViewController.h>
#import <YouTubeHeader/YTWrapperSplitViewController.h>

// For Settings.x and SponsorBlockSettings.x
#import <PSHeader/Misc.h>
#import <YouTubeHeader/YTSettingsGroupData.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTSettingsSectionController.h>
#import <YouTubeHeader/YTSearchableSettingsViewController.h>
#import <YouTubeHeader/YTUIUtils.h>

#define DownloadFix @"HPlusDownloadFix"
#define DownloadServerIndex @"HPlusDownloadServerIndex"
#define SABRDownload @"HPlusSABRDownload"
#define DownloadMethod @"HPlusDownloadMethod" // index into the "Download method" picker
#define DownloadMethodDirect 0   // YouTube's built-in stream URLs
#define DownloadMethodServer 1   // external server (triggerSilentDownload…)
#define DownloadMethodOnDevice 2 // on-device SABR engine

#define IS_ENABLED(k) [[NSUserDefaults standardUserDefaults] boolForKey:k]
#define INTFORVAL(v) [[NSUserDefaults standardUserDefaults] integerForKey:v]
#define FixPlaybackIssues @"HPlusFixPlaybackIssues"
#define MuteButton @"HPlusMuteButton"
#define SpeedButton @"HPlusSpeedButton"
#define ShareButton @"HPlusShareButton"
#define LoopButton @"HPlusLoopButton"
#define CaptionButton @"HPlusCaptionButton"
#define KeepMutedKey @"HPlusKeepMutedKey"
#define KeepLoopKey @"HPlusKeepLoopKey"
#define QualityButton @"HPlusQualityButton"
#define OverlayButtonOrder @"HPlusOverlayButtonOrder"
#define GlobalSpeedLocked @"HPlusGlobalSpeedLocked"
#define GlobalSavedNormalRate @"HPlusGlobalSavedNormalRate"
// Downloading
#define DownloadManager @"HPlusDownloadManager"
#define PostDownloadAction @"HPlusPostDownloadAction"
#define PostDownloadActionSaveToPhotos 0
#define PostDownloadActionShare 1
#define PostDownloadActionAsk 2
#define AddDownloadToShorts @"HPlusAddDownloadToShorts"
#define AudioPreferIndex @"HPlusAudioPreferIndex"
#define DownloadComment @"HPlusDownloadComment"
#define DownloadPost @"HPlusDownloadPost"
// Cache
#define AutoClearCache @"HPlusAutoClearCache"
// Appearance
#define OLEDTheme @"HPlusEnablesOLEDTheme"
#define OLEDKeyboard @"HPlusEnablesOLEDKeyboard"
// Navigation bar
#define YTLogoIndex @"HPlusYTLogoIndex"
#define StickyNavBar @"HPlusStickyNavBar"
#define HideNoti @"HPlusHideNotificationButton"
#define HideSearch @"HPlusHideSearchButton"
#define HideVoiceSearch @"HPlusHideVoiceSearchButton"
#define HideCastButtonNav @"HPlusHideCastButtonNavigationBar"
// Feed 
#define HideSubbar @"HPlusHideSubbar"
#define HideHoriShelf @"HPlusHideHoriShelf"
#define HideGenMusicShelf @"HPlusHideGenMusicShelf"
#define HideFeedPost @"HPlusHideFeedPost"
#define HidePlayables @"HPlusHidePlayables"
#define HideShortsShelf @"HPlusHideShortsShelf"
#define KeepShortsSubscript @"HPlusKeepShortsSubscript"
#define HideSearchHis @"HPlusHideSearchHistoryAndSuggestions"
#define HideSurveys @"HPlusHideSurveys"
#define HideRelatedVideos @"HPlusHideRelatedVideos"
#define RemoveChannelCommunityButton @"HPlusRemoveChannelCommunityButton"
#define RemoveChannelSponsorAll @"HPlusRemoveChannelSponsorAll"
// Player
#define WifiQualityIndex @"HPlusWifiQualityIndex"
#define CellQualityIndex @"HPlusCellQualityIndex"
#define LowPowerQualityIndex @"HPlusLowPowerQualityIndex"
#define AudioTrack @"HPlusAudioTrackSegment"
#define AudioTrackLangIndex @"HPlusAudioTrackLangIndex"
#define NoDubbedAudioTrack @"HPlusNoDubbedAudioTrack"
#define CaptionTrack @"HPlusCaptionTrack"
#define CaptionTrackLangIndex @"HPlusCaptionTrackLangIndex"
#define DisablesCaptionTrack @"HPlusDisablesCaptionTrack"
#define AutoSpeedIndex @"HPlusAutoSpeedIndex"
#define HoldToSpeedIndex @"HPlusHoldToSpeedIndex"
#define HideAutoPlayToggle @"HPlusHideAutoPlayToggle"
#define HideCaptionsButton @"HPlusHideCaptionsButton"
#define HideCastButtonPlayer @"HPlusHideCastButtonPlayer"
#define HideNextAndPrevButtons @"HPlusHideNextAndPrevButtons"
#define ReplacePrevNextButtons @"HPlusReplacePrevNextButtons"
#define SkipBackwardEnabled @"HPlusSkipBackwardEnabled"
#define SkipForwardEnabled @"HPlusSkipForwardEnabled"
#define RewindSeconds @"HPlusRewindSeconds"
#define ForwardSeconds @"HPlusForwardSeconds"
#define RemoveDarkOverlay @"HPlusRemoveDarkOverlay"
#define RemoveAmbiant @"HPlusRemoveAmbiantColors"
#define HideEndScreenCards @"HPlusHideEndScreenCards"
#define HideSuggestedVideo @"HPlusHideSuggestedVideoOnFinish"
#define HidePaidPromoOverlay @"HPlusHidePaidPromoOverlay"
#define HideWaterMark @"HPlusHideWaterMark"
#define DisablesEngagementPanel @"HPlusDisablesEngagementPanel"
#define DontSnapToChapter @"HPlusDontSnapToChapter"
#define PauseOnOverlay @"HPlusPauseOnOverlay"
#define GestureControls @"HPlusEnableGesturesControls"
#define GestureActivationArea @"HPlusGestureActivationArea"
#define LeftSideGesture @"HPlusLeftSideGesture"
#define RightSideGesture @"HPlusRightSideGesture"
#define GestureHUD @"HPlusGestureHUD"
#define GestureHUDSize @"HPlusGestureHUDSize"
#define GestureHUDPosition @"HPlusGestureHUDPosition"
#define DisablesDoubleTap @"HPlusDisablesDoubleTap"
#define DisablesLongHold @"HPlusDisablesLongHold"
#define AutoExitFullScreen @"HPlusAutoExitFullScreen"
#define DisablesShowRemaining @"HPlusDisablesShowRemainingTime"
#define AlwaysShowRemaining @"HPlusAlwaysShowRemainingTime"
#define ShowExtraTimeRemaining @"HPlusShowExtraTimeRemaining"
#define Uses24HoursTime @"HPlusUses24HoursTime"
#define CopyWithTimestampOnPause @"HPlusCopyWithTimestampOnPause"
#define HideFullAction @"HPlusHideFullScreenAction"
#define HideFullvidTitle @"HPlusHideFullscreenVideoTitle"
#define StopAutoplayVideo @"HPlusStopAutoplayVideo"
#define HideContentWarning @"HPlusHideContentWarning"
#define AutoFullScreen @"HPlusAutoFullScreen"
#define PortFull @"HPlusPortraitFullscreen"
#define OldQualityPicker @"HPlusUseOldQualityPicker"
#define ExtraSpeed @"HPlusAddExtraSpeed"
#define ForceMiniPlayer @"HPlusForceMiniPlayer"
#define AlwaysShowSeekbar @"HPlusAlwaysShowSeekbar"
#define DisablesFreeZoom @"HPlusDisablesFreeZoom"
#define TapToSeek @"HPlusTapToSeek"
#define PauseTwoFingers @"HPlusPauseTwoFingers"
#define HideCommentsSection @"HPlusHideCommentsSection"
#define HideCommentsPreview @"HPlusHideCommentsPreview"
#define LockSpeed @"HPlusLockSpeed"
#define SeekOnOverlay @"HPlusSeekOnOverlay"
#define AutoDRCAudioIndex @"HPlusAutoDRCAudioIndex"
#define RemoveVideoLikeButton @"HPlusRemoveVideoLikeButton"
#define RemoveVideoDislikeButton @"HPlusRemoveVideoDislikeButton"
#define RemoveVideoShareButton @"HPlusRemoveVideoShareButton"
#define RemoveVideoSaveButton @"HPlusRemoveVideoSaveButton"
#define RemoveVideoDownloadButton @"HPlusRemoveVideoDownloadButton"
#define RemoveVideoClipButton @"HPlusRemoveVideoClipButton"
#define RemoveVideoRemixButton @"HPlusRemoveVideoRemixButton"
#define RemoveVideoLiveChatButton @"HPlusRemoveVideoLiveChatButton"
#define AutoFeedMute @"HPlusAutoFeedMute"
// Shorts
#define HideShortsTopbar @"HPlusHideShortsTopbar"
#define HideShortsSubbar @"HPlusHideShortsSubbar"
#define FullScreenShorts @"HPlusFullScreenShorts"
#define RemoveShortsLive @"HPlusRemoveShortsLive"
#define RemoveShortsPosts @"HPlusRemoveShortsPosts"
#define HideShortsProducts @"HPlusHideShortsProducts"
#define HideShortsRecbar @"HPlusHideShortsRecbar"
#define EnablesShortsQuality @"HPlusEnablesShortsQuality"
#define ShowShortsSeekbar @"HPlusShowShortsSeekbar"
#define ShortsActionIndex @"HPlusMakeAShortsAction"
#define ShortsOnly @"HPlusShortsOnly"
#define RemoveShortsLikeButton @"HPlusRemoveShortsLikeButton"
#define RemoveShortsCommentButton @"HPlusRemoveShortsCommentButton"
#define RemoveShortsShareButton @"HPlusRemoveShortsShareButton"
#define RemoveShortsRemixButton @"HPlusRemoveShortsRemixButton"
#define RemoveShortsSoundMetadataButton @"HPlusRemoveShortsSoundMetadataButton"
#define RemoveShortsPausedSubButton @"HPlusRemoveShortsPausedSubButton"
#define RemoveShortsPausedLiveButton @"HPlusRemoveShortsPausedLiveButton"
#define RemoveShortsPausedLensButton @"HPlusRemoveShortsPausedLensButton"
#define RemoveShortsPausedTrendsButton @"HPlusRemoveShortsPausedTrendsButton"
#define RemoveShortsDisclosure @"HPlusRemoveShortsDisclosure"
#define RemoveShortsTitleButton @"HPlusRemoveShortsTitleButton"
#define RemoveShortsSaveButton @"HPlusRemoveShortsSaveButton"
// Tab bar
#define DefaultTab @"HPlusDefaultStartupTab"
#define TabOrder @"HPlusTabOrder"
#define HideTabIndi @"HPlusHideTabIndicators"
#define HideTabLabels @"HPlusHideTabLabels"
#define UseFrostedTabBar @"HPlusUseFrostedTabBar"
// Miscellaneous
#define BackgroundPlayback @"HPlusEnablesBackgroundPlayback"
#define DisablesShortsPiP @"HPlusTrytoDisablesShortsPiP"
#define DisableHints @"HPlusDisableHints"
#define BlockUpgradeDialogs @"HPlusBlockUpgradeDialogs"
#define HideAreYouThereDialog @"HPlusHideAreYouThereDialog"
#define FixesSlowMiniPlayer @"HPlusFixesSlowMiniPlayer"
#define DisablesNewMiniPlayer @"HPlusDisablesNewMiniPlayer"
#define DisablesSnackBar @"HPlusDisablesSnackBar"
#define HideStartupAni @"HPlusHideStartupAnimations"
#define HideLikeDislikeVotes @"HPlusHideLikeDislikeVotes"
#define HideCommuGuide @"HPlusHideCommuGuide"
#define HideEngagementSubbar @"HPlusHideEngagementSubbar"
#define DisablesRTL @"HPlusDisablesRTL"
#define DeviceUIIndex @"HPlusDeviceUIIndex"
#define FloatingKeyboard @"HPlusFloatingKeyboard"
#define AutoOpenLink @"HPlusAutoOpenLink"
// #define CustomStartup @"HPlusUseCustomVideoStartup"
// Flyout menu
#define RemovePlayInNextQueueOption @"HPlusRemovePlayInNextQueueOption"
#define RemoveDownloadOption @"HPlusRemoveDownloadOption"
#define RemoveWatchLaterOption @"HPlusRemoveWatchLaterOption"
#define RemoveSaveOption @"HPlusRemoveSaveOption"
#define RemoveRemoveFromPlaylistOption @"HPlusRemoveRemoveFromPlaylistOption"
#define RemoveShareOption @"HPlusRemoveShareOption"
#define RemoveNotInterestedOption @"HPlusRemoveNotInterestedOption"
#define RemoveInfoOption @"HPlusRemoveInfoOption"
#define RemoveFilterOption @"HPlusRemoveFilterOption"
#define RemoveReportOption @"HPlusRemoveReportOption"
#define RemoveYouTubeMusicOption @"HPlusRemoveYouTubeMusicOption"
#define RemoveFeedBackOption @"HPlusRemoveFeedBackOption"
#define RemoveDontRecommendOption @"HPlusRemoveDontRecommendOption"
#define RemoveCastOption @"HPlusRemoveCastOption"
#define RemoveShuffleOption @"HPlusRemoveShuffleOption"
#define RemoveUnSubOption @"HPlusRemoveUnSubOption"
#define RemoveHideFromPlaylistOption @"HPlusRemoveHideFromPlaylistOption"
#define RemoveHelpOption @"HPlusRemoveHelpOption"
#define RemoveNotifyOption @"HPlusRemoveNotifyOption"
#define RemoveClearScreenOption @"HPlusRemoveClearScreenOption"
#define RemoveAddToLastQueueOption @"HPlusRemoveAddToLastQueueOption"
// SponsorBlock
#define SBEnabled @"HPlusSBEnabled"
#define SBShowButton @"HPlusSBShowButton"
#define SBShowNotifications @"HPlusSBShowNotifications"
#define SBAudioNotification @"HPlusSBAudioNotification"
#define SBSegmentsInPlayer @"HPlusSBSegmentsInPlayer"
#define SBSegmentsInFeed @"HPlusSBSegmentsInFeed"
#define SBSegmentsInMiniPlayer @"HPlusSBSegmentsInMiniPlayer"
#define SBShowDuration @"HPlusSBShowDuration"
#define SBMinDuration @"HPlusSBMinDuration"
#define SBSkipAlertDuration @"HPlusSBSkipAlertDuration"
#define SBUnskipAlertDuration @"HPlusSBUnskipAlertDuration"
#define SBButtonKey @"HPlusSBButtonKey"

#define SB_ACTION_KEY(cat) [NSString stringWithFormat:@"HPlusSBAction_%@", cat]
#define SB_COLOR_KEY(cat) [NSString stringWithFormat:@"HPlusSBColor_%@", cat]

#define FLOAT_FOR_KEY(k) [[NSUserDefaults standardUserDefaults] floatForKey:k]

#define YT_BUNDLE_ID @"com.google.ios.youtube"
#define YT_NAME @"YouTube"

@interface MDCInkView : UIView
@end

@interface YTPageHeaderViewController : UIViewController
@end

@interface YTIPageHeaderRenderer : GPBMessage
@end

@interface YTDefaultSheetController (HPlus)
+ (instancetype)sheetControllerWithParentResponder:(id)parentResponder;
- (void)addAction:(YTActionSheetAction *)action;
- (void)presentFromView:(UIView *)view animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)presentFromViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)addHeaderWithTitle:(NSString *)arg1 subtitle:(NSString *)arg2;
@end

// Gesture Section Enum
typedef NS_ENUM(NSUInteger, GestureSection) {
    GestureSectionTop,
    GestureSectionBottom,
    GestureSectionInvalid
};

@interface YTWatchController (HPlus)
- (void)reload;
@end

@interface YTPlayerOverlayProvider (HPlus)
- (void)removePlayerOverlayWithIdentifier:(NSString *)identifier;
@end

@interface YTELMViewController : UIViewController
@end

@interface YTInlineScrubGestureView : UIView
@end

@interface YTPivotBarView : UIView
@end

@interface YTPivotBarItemView (HPlus) <UIContextMenuInteractionDelegate>
@end

@interface YTContextualWrapView : UIView
@end

@interface YTShortsAdsPlayerViewController : YTReelPlayerViewController
@end

@interface YTIBrowseRequest (HPlus)
+ (NSString *)browseIDForGamingDestination;
+ (NSString *)browseIDForSportsDestination;
+ (NSString *)browseIDForNotificationsInbox;
+ (NSString *)browseIDForHistory;
@end

@interface YTITopbarLogoRenderer : NSObject
@property(readonly, nonatomic) YTIIcon *iconImage;
@end

@interface YTRightNavigationButtons (HPlus)
@property (nonatomic, strong) YTQTMButton *notificationButton;
@property (nonatomic, strong) YTQTMButton *searchButton;
@end

@interface YTVideoFreeZoomOverlayController : NSObject
- (NSUInteger)state;
@end

@interface YTVideoFreeZoomOverlayView : UIView
@end

@interface YTMainAppVideoPlayerOverlayView (HPlus)
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@property (nonatomic, strong) YTQTMButton *playbackRouteButton;
- (YTVideoFreeZoomOverlayView *)videoFreeZoomOverlayView;
@end

@interface YTQTMButton (HPlus)
- (void)enableNewTouchFeedback;
@end

@interface YTHeaderView : UIView
- (void)setStickyNavHeaderEnabled:(BOOL)arg;
@end

@interface YTNavigationBarTitleView : UIView
@end

@interface YTSearchViewController : UIViewController
@end

@interface YTPlayabilityResolutionUserActionUIController : NSObject
- (void)confirmAlertDidPressConfirm;
@end

@interface YTPlayabilityResolutionUserActionUIControllerImpl : NSObject
- (void)confirmAlertDidPressConfirm;
@end

@interface YTPivotBarViewController : UIViewController
- (void)selectItemWithPivotIdentifier:(id)pivotIndentifier;
- (void)HPlusReloadTabBar:(id)arg;
@end

@interface YTReelWatchPlaybackOverlayView : UIView <UIGestureRecognizerDelegate>
@property (nonatomic, retain) UIPinchGestureRecognizer *HPlusFullscreenGesture;
@end

@interface YTReelContentView (HPlus) <UIGestureRecognizerDelegate>
@property (nonatomic, retain) UILongPressGestureRecognizer *HPlusExitShortsOnlyGesture;
- (YTReelWatchPlaybackOverlayView *)playbackOverlay;
@end

@interface YTLanguages : NSObject
+ (instancetype)languageList;
@end

@interface YTICaptionTrackEntry : GPBMessage
- (NSString *)baseURL;
- (NSString *)vssId;
- (NSString *)languageCode;
- (YTIFormattedString *)name;
@end

@interface YTPlayerViewController (HPlus) <UIGestureRecognizerDelegate>
@property (nonatomic, retain) UIPanGestureRecognizer *HPlusPanGesture;
@property (nonatomic, retain) UITapGestureRecognizer *HPlusTapGesture;
@property (nonatomic, retain) UILabel *HPlusGestureHUD;
@property (nonatomic, weak, readwrite) UIViewController *parentViewController;
@property (nonatomic, assign, readonly) BOOL isInlinePlaybackActive;
@property (nonatomic, assign, readonly) BOOL isPlayingAd;
@property (nonatomic, strong) UIView *HPlusSpeedToastView;
@property (nonatomic, strong) UILabel *HPlusSpeedToastLabel;
@property (nonatomic, retain) UILongPressGestureRecognizer *HPlusHoldGesture;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
- (void)HPlusAutoFullscreen;
- (void)HPlusSetAutoSpeed;
- (void)setPlaybackRate:(float)rate;
- (void)setActiveCaptionTrack:(MLInnerTubeCaptionTrack *)arg1 source:(NSInteger)arg2;
- (void)setActiveCaptionTrack:(MLInnerTubeCaptionTrack *)arg;
- (void)play;
- (void)pause;
- (void)HPlusAutoMute;
- (void)HPlusAutoAudioTrack;
- (void)HPlusAutoCaptions;
- (void)HPlusLoopButton;
- (void)HPlusCaptionsHelper:(MLInnerTubeCaptionTrack *)arg;
- (void)HPlusShareButton:(UIView *)sourceView;
- (NSInteger)playerState;
- (YTPlayerResponse *)contentPlayerResponse;
- (YTPlayerResponse *)playerResponse;
- (id)audioTrackController;
- (void)HPlusHideSpeedToast;
- (void)HPlusShowSpeedToast:(CGFloat)speed isLocked:(BOOL)isLocked;
- (void)HPlusAutoDRCAudio;
- (void)setAudioTrack:(YTIAudioTrack *)arg1 source:(NSInteger)arg2;
- (void)setAudioDRCEnabled:(BOOL)arg;
@end

@interface YTPlayerBarController (HPlus)
- (void)didScrub:(UIPanGestureRecognizer *)gesture;
@end

@interface YTFullscreenEngagementOverlayView : UIView
@end

@interface YTFullscreenActionsView : UIView
@end

@interface YTAnnotationsViewController : UIViewController
@end

@interface YTRelatedVideosView : UIView
@end

@interface YTAutoplayAutonavController : NSObject
- (void)setLoopMode:(NSInteger)loopMode;
@end

@interface YTInlineMutedPlaybackPlayerOverlayViewController : UIViewController
@end

@interface YTInlineMutedPlaybackPlayerOverlayView : UIView
@end

@interface YTWatchFloatingMiniplayerViewController : UIViewController
@end

@interface YTWatchFloatingMiniplayerWithPersistentControlsView : UIView
@end

@interface YTWatchFloatingMiniplayerProgressBarView : UIView
@end

@interface SSOConfiguration : NSObject
@end

@interface ASDisplayNode (HPlus)
- (void)removeYogaChild:(id)arg;
@end

@interface YTIMySubsFilterHeaderRenderer : GPBMessage
@end

@interface YTMySubsFilterHeaderViewController : UIViewController
@end

@interface YTEngagementPanelView : UIView
@end

@interface YTEngagementPanelContainerView : UIView
- (NSInteger)engagementPanelState;
@end

@interface YTRelatedVideosViewController : UIViewController
- (BOOL)isExpanded;
@end

@interface YTMainAppControlsOverlayView (HPlus)
- (YTMainAppVideoPlayerOverlayViewController *)eventsDelegate;
@end

@interface YTVideoQualitySwitchOriginalController (HPlus)
@property (retain, nonatomic) YTVideoQualitySwitchRedesignedController *redesignedController;
@end

@interface UIView (HPlus)
@property (nonatomic, assign, readonly) BOOL _mapkit_isDarkModeEnabled;
- (UIViewController *)_viewControllerForAncestor;
@end

@interface UIKeyboard : UIView // Regular keyboard
+ (instancetype)activeKeyboard;
@end

@interface UIPredictionViewController : UIViewController // Keyboard with enabled predictions panel
@end

@interface UIKeyboardDockView : UIView // Dock under keyboard for notched devices
@end

@interface UIKBVisualEffectView : UIVisualEffectView
@property (nonatomic, copy, readwrite) NSArray *backgroundEffects;
@end

@interface YTAppDelegate : UIResponder
- (void)HPlusAutoClearCache;
@end

@interface YTInlinePlayerBarContainerView (HPlus)
@property (nonatomic, strong) NSString *endTimeString;
@end

// Custom perferences logics
@interface HPlusPrefsManager : NSObject <UIDocumentPickerDelegate>
+ (instancetype)sharedManager;
- (void)exportHPlusSettingsFromVC:(UIViewController *)vc;
- (void)importHPlusSettingsFromVC:(UIViewController *)vc;
- (void)restoreHPlusDefaults;
@end

@interface YTIAudioTrack (HPlus)
@property (nonatomic, assign, readwrite) BOOL isAutoDubbed;
- (BOOL)hasId_p;
@end

@interface MLInnerTubeCaptionTrack (HPlus)
- (NSString *)languageCode;
- (NSString *)VSSID;
@end

@interface YTCaptionTrackSwitchController : NSObject
@end

@interface ASScrollView : UIScrollView
- (id)scrollNode;
@end

// Player Gestures - @bhackel (YTLitePlus)
@interface YTMainAppVideoPlayerOverlayViewController (HPlus)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
- (YTCaptionTrackSwitchController *)captionTrackController;
- (NSString *)videoID;
- (CGFloat)mediaTime;
@end

@interface YTSingleVideo (HPlus)
- (BOOL)isLivePlayback;
@end

@interface YTSingleVideoController (HPlus)
- (CGFloat)totalMediaTime;
- (void)setVideoFormatConstraint:(id)arg;
- (void)HPlusAutoQuality;
- (NSArray *)availableCaptionTracks;
- (MLInnerTubeCaptionTrack *)activeCaptionTrack;
@end

@interface YTReelPlayerViewController (HPlus)
- (void)reelContentViewRequestsAdvanceToNextVideo:(id)arg;
- (void)reelContentViewRequestsPlayPauseToggle:(id)arg;
- (id)audioTrackController;
- (void)HPlusAutoAudioTrack:(YTPlayerViewController *)pv;
@end

@interface YTIPlayerCaptionsTrackListRenderer : GPBMessage
- (NSMutableArray *)captionTracksArray;
@end

@interface YTICaptionsSupportedRenderers : GPBMessage
- (YTIPlayerCaptionsTrackListRenderer *)playerCaptionsTracklistRenderer;
@end

@interface YTIPlayerResponse (HPlus)
- (YTIStreamingData *)streamingData;
- (YTICaptionsSupportedRenderers *)captions;
@end

@interface YTIFormatStream (HPlus)
- (NSString *)mimeType;
- (NSInteger)contentLength;
- (NSUInteger)approxDurationMs;
- (int)height;
- (int)fps;
- (YTIAudioTrack *)audioTrack;
- (int)itag;
@end

@interface YTIFormattedString (HPlus)
- (NSString *)dropdownOptionTitle;
@end

@interface YTIVideoDetails (HPlus)
- (NSString *)title;
- (NSString *)author;
- (NSString *)shortDescription;
- (YTIThumbnailDetails *)thumbnail;
@end

@interface YTDataUtils : NSObject
+ (instancetype)generateClientSideNonce;
@end

@interface YCHAsyncLiveChatCollectionViewController : UIViewController
@end

@interface YTStartupAnimationViewController : UIViewController
@end

@interface YTWatchFloatingMiniplayerBadgeView : UIView
@end

@interface YTInlineMutedPlaybackScrubberViewController : UIViewController
@end

@interface YTReelTopBarView : UIView
@end

// SponsorBlock action modes
typedef NS_ENUM(NSInteger, SBSegmentAction) {
    SBSegmentActionDisable = 0,
    SBSegmentActionAutoSkip = 1,
    SBSegmentActionAsk = 2,
    SBSegmentActionDisplay = 3,
    SBSegmentActionSkipTo = 4
};

@interface SBSegment : NSObject
@property (nonatomic, strong) NSString *UUID;
@property (nonatomic, strong) NSString *category;
@property (nonatomic, assign) float startTime;
@property (nonatomic, assign) float endTime;
@property (nonatomic, strong) NSString *actionType;
+ (instancetype)segmentWithUUID:(NSString *)UUID category:(NSString *)category start:(float)start end:(float)end action:(NSString *)actionType;
- (SBSegmentAction)configuredAction;
- (UIColor *)segmentColor;
@end

@interface SBRequest : NSObject
+ (void)fetchSegmentsForVideoID:(NSString *)videoID completion:(void (^)(NSArray<SBSegment *> *segments))completion;
@end

@interface SBSkipNotificationView : UIView
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIView *progressOverlay;
@property (nonatomic, copy) void (^onAction)(void);
@property (nonatomic, assign) NSTimeInterval totalDuration;
@property (nonatomic, assign) NSTimeInterval remainingDuration;
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) BOOL isHighlightPill;
@property (nonatomic, strong) NSDate *backgroundDate;
+ (instancetype)showInView:(UIView *)parentView message:(NSString *)message buttonTitle:(NSString *)buttonTitle action:(void (^)(void))action duration:(NSTimeInterval)duration;
+ (instancetype)showDownloadCompleteDialogInView:(UIView *)parentView message:(NSString *)message saveHandler:(void (^)(void))saveHandler shareHandler:(void (^)(void))shareHandler duration:(NSTimeInterval)duration;
+ (instancetype)showSuccessInView:(UIView *)parentView message:(NSString *)message duration:(NSTimeInterval)duration;
+ (instancetype)showErrorInView:(UIView *)parentView message:(NSString *)message duration:(NSTimeInterval)duration;
- (void)dismiss;
- (void)pauseProgress;
- (void)resumeProgress;
@end

extern UIView *sbGetNotificationParent(void);
extern void sbUpdateOverlayInsetForPivotBar(void);
extern void YMPresentTabOrderModally(id parentResponder);

// The ordered set of SponsorBlock categories HPlus supports. Both the core
// (segment fetching / skipping) and the settings UI read from this single list,
// so a category can never be fetchable without a control, or configurable
// without being fetched.
extern NSArray<NSString *> *sbAllCategories(void);

// Tag stamped on every seek-bar segment marker view, used to find and remove
// them across the player-bar layout hooks that don't hold a direct reference.
static const NSInteger SBSegmentMarkerTag = 9900;

// Supported range and default for the skip/unskip banner duration (seconds).
// The settings sliders expose this range and the core clamps stored values to
// it, so both read from one source and can never drift out of agreement.
static const CGFloat SBAlertDurationMin = 2.0;
static const CGFloat SBAlertDurationMax = 20.0;
static const CGFloat SBAlertDurationDefault = 4.0;

#pragma mark - Custom Overlay Button Registry

// A registered button shown in the player's controls overlay (top-right, under
// YouTube's settings gear). Features register a spec from their own %ctor; the
// single YTMainAppControlsOverlayView hook in OverlayButtons.x lays them all out.
@interface YMOverlayButtonSpec : NSObject
@property (nonatomic, copy) NSString *identifier;       // unique, e.g. @"sponsorblock.toggle"
@property (nonatomic, copy) NSString *symbolName;       // SF Symbol name (icon button)
@property (nonatomic, copy) NSString *title;            // text label; set this instead of symbolName for a text button
@property (nonatomic, copy) NSString *displayName;      // localized display name for settings
@property (nonatomic, copy) NSString *settingsSymbolName; // custom symbol name for settings table view
@property (nonatomic, strong) UIColor *tintColor;       // default tint (used if tintProvider is nil)
@property (nonatomic, assign) NSInteger sortOrder;      // ascending; lower = closer to gear (rightmost)
@property (nonatomic, copy) void (^onTap)(YTPlayerViewController *player, YTQTMButton *button);
@property (nonatomic, copy) BOOL (^isVisible)(YTPlayerViewController *player);     // nil = always visible
@property (nonatomic, copy) UIColor *(^tintProvider)(YTPlayerViewController *player); // nil = use tintColor
@property (nonatomic, assign) NSInteger viewTag;        // assigned by the registry; do not set
@end

extern void YMRegisterOverlayButton(YMOverlayButtonSpec *spec);
extern NSArray<YMOverlayButtonSpec *> *YMRegisteredOverlayButtons(void);
extern NSArray<YMOverlayButtonSpec *> *YMOrderedOverlayButtons(void);
extern BOOL YMIsOverlayButtonEnabled(NSString *identifier);
extern void YMPushOverlayButtonOrder(id settingsVC, id parentResponder);

#pragma mark - Settings Search

// One row in the global settings-search results. A row renders its own cell and
// (optionally) handles its own tap, so a single results table can host cells from
// different settings pages (the generic HPlus pages and SponsorBlock) without the
// search controller knowing how any of them are built. searchText is what the query
// is matched against (title + description). makeCell builds the live, editable
// control; onSelect handles taps that need to present UI (e.g. the colour picker),
// receiving the presenting VC and a reload block to refresh the results.
@interface YMSearchRow : NSObject
@property (nonatomic, copy) NSString *searchText;
@property (nonatomic, copy) UITableViewCell *(^makeCell)(UITableView *tableView);
@property (nonatomic, assign) CGFloat cellHeight; // 0 = UITableViewAutomaticDimension
@property (nonatomic, copy) void (^onSelect)(UIViewController *presenter, void (^reload)(void));
@end

// SponsorBlock's searchable rows (toggles, sliders, per-category action pickers and
// colour circles), rendered by SponsorBlock's own cell builders so its settings are
// editable inline in the global search. host adopts the rendering VC as a child so
// the cells inherit the correct trait collection (light/dark). Defined in
// SponsorBlockSettings.x; consumed by the search VC in HPlusSettings.x.
extern NSArray<YMSearchRow *> *sbSearchRows(UIViewController *host);

extern NSBundle *HPlusBundle();
extern UIImage *HPlusYTIconImage(NSInteger iconType, BOOL useCustomColor, UIColor *customColor);
extern NSArray *getAllSystemLanguageTitles();
extern NSArray *getAllSystemLanguageValues();
extern UIViewController *HPlusTopViewController(UIViewController *root);
extern BOOL isDarkMode(UIView *view);
extern BOOL isPad();

#define LOC(x) [HPlusBundle() localizedStringForKey:x value:nil table:nil]

@interface YMDownloadProgressView : UIView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, copy) void (^onCancel)(void);
+ (instancetype)showInView:(UIView *)parentView message:(NSString *)message cancelAction:(void (^)(void))cancelAction;
- (void)updateProgress:(float)progress title:(NSString *)title subtitle:(NSString *)subtitle;
- (void)dismiss;
@end

@interface YTPlayerViewController (SponsorBlock)
@property (nonatomic, strong) NSString *sbLastVideoID;
@property (nonatomic, strong) NSArray<SBSegment *> *sbSegments;
@property (nonatomic, strong) NSMutableSet<NSString *> *sbSkippedSegments;
@property (nonatomic, strong) SBSkipNotificationView *sbNotificationView;
- (void)sbCheckSegmentsAtCurrentTime;
- (void)sbPerformSkip:(SBSegment *)segment;
- (void)sbShowAskNotification:(SBSegment *)segment;
- (void)sbShowHighlightBannerIfNeeded:(NSArray<SBSegment *> *)segments;
- (void)sbSkipToHighlight;
- (void)sbRefreshMarkers:(NSArray<SBSegment *> *)segments;
@end

@interface HPlusThumbnailViewController : UIViewController <UIScrollViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIImage *thumbnailImage;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@end

typedef NS_ENUM(NSInteger, HPlusTranslationState) {
    HPlusTranslationStateLoading = 0,
    HPlusTranslationStateSuccess = 1,
    HPlusTranslationStateFailed = 2
};

@interface HPlusTranslationViewController : UIViewController
@property (nonatomic, copy) NSString *originalText;
@property (nonatomic, strong) UILabel *langValueLabel;
@property (nonatomic, strong) UIButton *reloadButton;
@property (nonatomic, strong) UITextView *resultTextView;
@property (nonatomic, copy) NSString *selectedLangCode;
@property (nonatomic, copy) NSString *selectedLangName;
@property (nonatomic, strong) NSArray<NSString *> *languageTitles;
@property (nonatomic, strong) NSArray<NSString *> *languageCodes;
@property (nonatomic, assign) HPlusTranslationState translationState;
- (void)performTranslation;
@end

@interface HPlusLanguagePickerViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate>
@property (nonatomic, copy) NSString *selectedLangCode;
@property (nonatomic, copy) NSArray<NSString *> *titles;
@property (nonatomic, copy) NSArray<NSString *> *codes;
@property (nonatomic, copy) void (^onSelectLanguage)(NSString *code, NSString *title);
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *containerView;
@end

// On-device SABR downloader (SABRDownload.x). Produces two elementary files (video
// mp4 + audio m4a) for the existing muxer; progress/completion on the main queue.
@interface YMSABR : NSObject
+ (void)downloadVideoItag:(int)videoItag audioItag:(int)audioItag
                 progress:(void (^)(float fraction, unsigned long long bytesDownloaded, BOOL isAudio))progress
               completion:(void (^)(NSURL *videoURL, NSURL *audioURL, NSString *err))completion;
+ (void)downloadAudioItag:(int)audioItag
                 progress:(void (^)(float fraction, unsigned long long bytesDownloaded))progress
               completion:(void (^)(NSURL *audioURL, NSString *err))completion;
+ (void)cancelCurrent;
@end