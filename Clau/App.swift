import SwiftUI

@main
struct ClauApp: App {
    @StateObject private var audio = AudioEngine()
    @StateObject private var progress = LessonProgress(defaults: ClauApp.isTest ? (UserDefaults(suiteName: "prova") ?? .standard) : .standard)

    /// Les proves automàtiques obren l'app amb «-prova»: sense micròfon i sense desar el progrés.
    static let isTest = ProcessInfo.processInfo.arguments.contains("-prova")

    var body: some Scene {
        WindowGroup {
            CourseView()
                .onAppear { if ClauApp.isTest { progress.reset() } }
                .environmentObject(audio)
                .environmentObject(progress)
                .preferredColorScheme(.light)
        }
    }
}
