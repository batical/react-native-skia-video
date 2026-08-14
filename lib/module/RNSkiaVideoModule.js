"use strict";

import { Platform } from 'react-native';
import NativeReactNativeSkiaVideo from "./NativeReactNativeSkiaVideo.js";
if (!NativeReactNativeSkiaVideo) {
  throw new Error(`The package '@azzapp/react-native-skia-video' doesn't seem to be linked. Make sure: \n\n` + Platform.select({
    ios: "- You have run 'pod install'\n",
    default: ''
  }) + '- You rebuilt the app after installing the package\n' + '- You are not using Expo Go\n');
}
const installed = NativeReactNativeSkiaVideo.install();
if (!installed || global.RNSkiaVideo == null) {
  throw new Error("The package '@azzapp/react-native-skia-video' failed to install its JSI bindings.");
}
export default global.RNSkiaVideo;
//# sourceMappingURL=RNSkiaVideoModule.js.map