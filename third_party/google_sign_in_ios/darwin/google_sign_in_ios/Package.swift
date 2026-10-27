// swift-tools-version: 5.9

// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// Vendored from google_sign_in_ios 6.3.8. Google Sign-In 10.1.0 can use the
// same GTMSessionFetcher range as firebase-ios-sdk 13. The published plugin
// still requires Google Sign-In 9. Remove this copy when pub.dev ships a
// google_sign_in_ios that depends on Google Sign-In 10.1.0.

import PackageDescription

let package = Package(
  name: "google_sign_in_ios",
  platforms: [
    .iOS("15.0"),
    .macOS("12.0"),
  ],
  products: [
    .library(name: "google-sign-in-ios", targets: ["google_sign_in_ios"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/google/GoogleSignIn-iOS.git",
      from: "10.1.0")
  ],
  targets: [
    .target(
      name: "google_sign_in_ios",
      dependencies: [
        .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
      ],
      resources: [
        .process("Resources")
      ]
    )
  ]
)
