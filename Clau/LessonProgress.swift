import Foundation

/// Quines lliçons s'han acabat. Es desa a l'aparell i enlloc més.
final class LessonProgress: ObservableObject {
    @Published private(set) var done: Set<String>

    private let key = "lessons.done"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        done = Set(defaults.stringArray(forKey: key) ?? [])
    }

    func isDone(_ lesson: Lesson) -> Bool { done.contains(lesson.id) }

    func complete(_ lesson: Lesson) {
        guard !done.contains(lesson.id) else { return }
        done.insert(lesson.id)
        defaults.set(Array(done).sorted(), forKey: key)
    }

    /// La primera lliçó que encara no s'ha fet.
    var next: Lesson? { Course.allLessons.first { !done.contains($0.id) } }

    func reset() {
        done = []
        defaults.removeObject(forKey: key)
    }
}
