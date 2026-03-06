// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoidMail",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "VoidMail", targets: ["VoidMail"])
    ],
    dependencies: [
        // Uncomment for production:
        // .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "VoidMail",
            dependencies: [
                // .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                // .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS"),
            ],
            path: "VoidMail"
        )
    ]
)
