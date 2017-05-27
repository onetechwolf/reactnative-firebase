package io.invertase.firebase.admob;


import android.app.Activity;
import android.util.Log;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.google.android.gms.ads.AdRequest;
import io.invertase.firebase.Utils;

import java.util.HashMap;
import java.util.List;
import java.util.Map;


public class RNFirebaseAdMob extends ReactContextBaseJavaModule {

  private static final String TAG = "RNFirebaseAdmob";

  ReactApplicationContext getContext() {
    return getReactApplicationContext();
  }

  Activity getActivity() {
    return getCurrentActivity();
  }

  private HashMap<String, RNFirebaseAdmobInterstitial> interstitials = new HashMap<>();
  private HashMap<String, RNFirebaseRewardedVideo> rewardedVideos = new HashMap<>();

  public RNFirebaseAdMob(ReactApplicationContext reactContext) {
    super(reactContext);
    Log.d(TAG, "New instance");
  }

  @Override
  public String getName() {
    return TAG;
  }

  @ReactMethod
  public void interstitialLoadAd(String adUnit, ReadableMap request) {
    RNFirebaseAdmobInterstitial interstitial = getOrCreateInterstitial(adUnit);
    interstitial.loadAd(buildRequest(request).build());
  }

  @ReactMethod
  public void interstitialShowAd(String adUnit) {
    RNFirebaseAdmobInterstitial interstitial = getOrCreateInterstitial(adUnit);
    interstitial.show();
  }

  @ReactMethod
  public void rewardedVideoLoadAd(String adUnit, ReadableMap request) {
    RNFirebaseRewardedVideo rewardedVideo = getOrCreateRewardedVideo(adUnit);
    rewardedVideo.loadAd(buildRequest(request).build());
  }

  @ReactMethod
  public void rewardedVideoShowAd(String adUnit) {
    RNFirebaseRewardedVideo rewardedVideo = getOrCreateRewardedVideo(adUnit);
    rewardedVideo.show();
  }

  private RNFirebaseAdmobInterstitial getOrCreateInterstitial(String adUnit) {
    if (interstitials.containsKey(adUnit)) {
      return interstitials.get(adUnit);
    }
    RNFirebaseAdmobInterstitial interstitial = new RNFirebaseAdmobInterstitial(adUnit, this);
    interstitials.put(adUnit, interstitial);
    return interstitial;
  }

  private RNFirebaseRewardedVideo getOrCreateRewardedVideo(String adUnit) {
    if (rewardedVideos.containsKey(adUnit)) {
      return rewardedVideos.get(adUnit);
    }
    RNFirebaseRewardedVideo rewardedVideo = new RNFirebaseRewardedVideo(adUnit, this);
    rewardedVideos.put(adUnit, rewardedVideo);
    return rewardedVideo;
  }

  @Override
  public Map<String, Object> getConstants() {
    final Map<String, Object> constants = new HashMap<>();
    constants.put("DEVICE_ID_EMULATOR", AdRequest.DEVICE_ID_EMULATOR);
    return constants;
  }

  AdRequest.Builder buildRequest(ReadableMap request) {
    AdRequest.Builder requestBuilder = new AdRequest.Builder();

    if (request.hasKey("testDevice")) {
      requestBuilder.addTestDevice(AdRequest.DEVICE_ID_EMULATOR);
    }

    ReadableArray keywords = request.getArray("keywords");
    List<Object> keywordsList = Utils.recursivelyDeconstructReadableArray(keywords);

    for (Object word : keywordsList) {
      requestBuilder.addKeyword((String) word);
    }

    return requestBuilder;
  }
}