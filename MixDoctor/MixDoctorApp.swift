//
//  MixDoctorApp.swift
//  MixDoctor
//
//  Created by Yevgeny Levin on 17/10/2025.
//

import SwiftUI
import SwiftData
import StoreKit
import FirebaseCore
import FirebaseAnalytics

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Skip Firebase during tests
        guard !AppDelegate.isRunningTests else { return true }

        FirebaseApp.configure()

        // Log app launch event
        Analytics.logEvent("app_launched", parameters: nil)

        return true
    }

    /// Returns true if the app is running under XCTest
    static var isRunningTests: Bool {
        return NSClassFromString("XCTestCase") != nil ||
               ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

@main
struct MixDoctorApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @State private var modelContainer: ModelContainer
    @State private var subscriptionService = SubscriptionService.shared
    @State private var iCloudMonitor = iCloudSyncMonitor.shared
    @State private var showWelcomeMessage = false
    @State private var showLaunchScreen = true
    @StateObject private var ratingService: RatingService
    @Environment(\.requestReview) private var requestReview
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    init() {
        // Configure Mac Catalyst fonts
        #if targetEnvironment(macCatalyst)
        Self.configureMacCatalystFonts()
        #endif
        
        // Check if user has enabled iCloud sync (default to true for better UX)
        // Disable iCloud during tests to prevent crashes
        let isRunningTests = AppDelegate.isRunningTests
        let iCloudEnabled = isRunningTests ? false : (UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true)
        
        do {
            let schema = Schema([AudioFile.self])
            
            // Get the application support directory
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let storeURL = appSupportURL.appendingPathComponent("MixDoctor.store")
            
            // Schema version tracking for migration
            // IMPORTANT: Only increment this when the schema actually changes
            // Incrementing this will DELETE the entire database!
            let currentSchemaVersion = 4
            let lastSchemaVersion = UserDefaults.standard.integer(forKey: "lastSchemaVersion")
            
            // If there's a corrupted store or schema changed, delete it
            // WARNING: This deletes all data! Only do this if schema actually changed.
            if FileManager.default.fileExists(atPath: storeURL.path) {
                // Check if we had a migration failure or schema version changed
                if UserDefaults.standard.bool(forKey: "hadMigrationFailure") || (lastSchemaVersion > 0 && lastSchemaVersion < currentSchemaVersion) {
                    print("⚠️ Schema version changed from \(lastSchemaVersion) to \(currentSchemaVersion) - database will be reset")
                    print("⚠️ Analysis results should be restored from JSON files via loadMissingAnalysisResults()")
                    try? FileManager.default.removeItem(at: storeURL)
                    // Also clean up any -wal or -shm files
                    try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent().appendingPathComponent("MixDoctor.store-wal"))
                    try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent().appendingPathComponent("MixDoctor.store-shm"))
                    UserDefaults.standard.removeObject(forKey: "hadMigrationFailure")
                    UserDefaults.standard.set(currentSchemaVersion, forKey: "lastSchemaVersion")
                }
            }
            
            // Configure CloudKit integration
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: iCloudEnabled ? .automatic : .none
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            
            // Save schema version on successful initialization
            UserDefaults.standard.set(currentSchemaVersion, forKey: "lastSchemaVersion")
            
        } catch {
            // Mark that we had a failure and try to delete and recreate
            UserDefaults.standard.set(true, forKey: "hadMigrationFailure")
            
            // Delete the store and try again
            do {
                let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let storeURL = appSupportURL.appendingPathComponent("MixDoctor.store")
                
                try? FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent().appendingPathComponent("MixDoctor.store-wal"))
                try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent().appendingPathComponent("MixDoctor.store-shm"))
                
                let schema = Schema([AudioFile.self])
                let modelConfiguration = ModelConfiguration(
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: .none  // Fallback to local only on error
                )
                modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                
                
                // Clear the failure flag since it worked
                UserDefaults.standard.removeObject(forKey: "hadMigrationFailure")
            } catch {
                fatalError("Could not create ModelContainer even after deleting store: \(error)")
            }
        }
        _ratingService = StateObject(wrappedValue: RatingService.shared)
    }
    
    #if targetEnvironment(macCatalyst)
    private static func configureMacCatalystFonts() {
        // Scale all UIKit fonts by 1.4x (40% larger) for Mac Catalyst
        let fontScale: CGFloat = 1.4
        
        // Navigation bar fonts
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34 * fontScale, weight: .bold)
        ]
        navBarAppearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17 * fontScale, weight: .semibold)
        ]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        
        // Tab bar fonts and styling
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        
        let tabBarItemAppearance = UITabBarItemAppearance()
        tabBarItemAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10 * fontScale)
        ]
        tabBarItemAppearance.selected.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10 * fontScale)
        ]
        tabBarAppearance.stackedLayoutAppearance = tabBarItemAppearance
        tabBarAppearance.inlineLayoutAppearance = tabBarItemAppearance
        tabBarAppearance.compactInlineLayoutAppearance = tabBarItemAppearance
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    #endif
    
    // Main content view (extracted for reuse)
    private var mainContentView: some View {
        ContentView()
            .modelContainer(modelContainer)
            .environmentObject(ratingService)
            .macCatalystFontScaling(1.5) // Scale entire UI by 50% on Mac
            .onChange(of: ratingService.shouldTriggerRating) { _, shouldTrigger in
                if shouldTrigger {
                    requestReview()
                }
            }
            .task {
                // Skip these services during tests
                guard !AppDelegate.isRunningTests else { return }

                // Check subscription status on launch
                await subscriptionService.updateCustomerInfo()

                // Defer iCloud monitoring to avoid blocking launch
                // Start monitoring after a short delay to let UI render first
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                iCloudMonitor.startMonitoring()
            }
            .onReceive(NotificationCenter.default.publisher(for: .iCloudSyncToggled)) { _ in
                // User needs to restart app for iCloud sync changes to take effect
            }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app content or onboarding
                if showLaunchScreen {
                    // Launch screen shows first
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(2)
                } else {
                    // After launch screen, show onboarding only if not completed
                    if !hasCompletedOnboarding {
                        OnboardingView(isPresented: Binding(
                            get: { !hasCompletedOnboarding },
                            set: { newValue in
                                if !newValue {
                                    // User completed or skipped onboarding - save completion
                                    hasCompletedOnboarding = true
                                }
                            }
                        ))
                        .zIndex(1)
                    } else {
                        mainContentView
                    }
                }
            }
            .onAppear {
                // Hide launch screen after animation
                // Hide launch screen after animation (matched to audio length: 3 bars @ 120bpm = 6s + delay)
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showLaunchScreen = false
                    }
                }
                
                #if targetEnvironment(macCatalyst)
                // Hide window title on Mac and enable responsive window resizing
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    if let titlebar = windowScene.titlebar {
                        titlebar.titleVisibility = .hidden
                    }
                    
                    // Get screen size for window sizing
                    let screenSize = windowScene.screen.bounds.size
                    let screenWidth = screenSize.width
                    let screenHeight = screenSize.height
                    
                    // Set minimum and maximum sizes for responsive window sizing
                    // Minimum width is fixed at 1800 as requested
                    if let sizeRestrictions = windowScene.sizeRestrictions {
                        // Fixed minimum width of 1800, ensure it doesn't exceed screen size
                        let minimumWidth: CGFloat = min(1800, screenWidth * 0.98)
                        let minimumHeight: CGFloat = 900
                        
                        // Maximum sizes: allow full screen expansion (green button + ALT+SHIFT)
                        // Set to screen dimensions to allow full screen
                        let maximumWidth: CGFloat = screenWidth
                        let maximumHeight: CGFloat = screenHeight
                        
                        sizeRestrictions.minimumSize = CGSize(width: minimumWidth, height: minimumHeight)
                        sizeRestrictions.maximumSize = CGSize(width: maximumWidth, height: maximumHeight)
                    }
                    
                    // Set initial window size to fit entire screen on launch
                    if let window = windowScene.windows.first {
                        // Make window fill entire screen - use full screen dimensions
                        let windowWidth = screenWidth
                        let windowHeight = screenHeight
                        
                        // Position window at origin (0,0) to fill entire screen
                        window.frame = CGRect(
                            x: 0,
                            y: 0,
                            width: windowWidth,
                            height: windowHeight
                        )
                    }
                }
                #endif
            }
        }
    }
}
