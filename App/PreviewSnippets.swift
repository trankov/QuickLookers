import Foundation

/// Показательные сниппеты для живого превью темы. Порядок = порядок сегментов.
/// Каждый несёт строки, числа, комментарии, ключевые слова — чтобы тема «играла».
/// Набор подобран под частые форматы (TS опущен — он визуально как JS; Swift —
/// его пишут в Xcode, превью не нужно).
enum PreviewSnippets {
    static let all: [(id: String, name: String, code: String)] = [
        ("python", "Python", #"""
        from dataclasses import dataclass

        @dataclass
        class Circle:
            radius: float

            def area(self) -> float:
                return 3.14159 * self.radius ** 2

        circles = [Circle(r) for r in (1.0, 2.5, 4.0)]
        total = sum(c.area() for c in circles)
        print(f"total area = {total:.2f}")  # comment
        """#),

        ("html", "HTML", #"""
        <!DOCTYPE html>
        <html lang="ru">
          <head>
            <meta charset="utf-8">
            <title>\#(String(localized: "Preview"))</title>
          </head>
          <body>
            <h1 class="title">\#(String(localized: "Hello, world"))</h1>
            <!-- \#(String(localized: "action button")) -->
            <button data-id="42" onclick="run()">\#(String(localized: "Run"))</button>
          </body>
        </html>
        """#),

        ("css", "CSS", #"""
        :root {
          --accent: #3b82f6;
          --radius: 8px;
        }

        .card {
          padding: 12px 16px;
          border-radius: var(--radius);
          background: linear-gradient(180deg, #fff, #f3f4f6);
          box-shadow: 0 1px 3px rgba(0, 0, 0, 0.12);
        }

        .card:hover { transform: translateY(-2px); }
        """#),

        ("json", "JSON", #"""
        {
          "name": "quicklookers",
          "version": 1,
          "enabled": true,
          "tags": ["code", "preview", "shiki"],
          "limits": { "maxLines": 2000, "cacheMB": 5 },
          "ratio": 0.75
        }
        """#),

        ("javascript", "JS", #"""
        // \#(String(localized: "word count in a string"))
        function wordCount(text) {
          const words = text.trim().split(/\s+/);
          return words.filter(Boolean).length;
        }

        const sample = `hello   world
        from quicklookers`;
        console.log(`words: ${wordCount(sample)}`); // words: 3
        """#),

        ("sql", "SQL", #"""
        -- \#(String(localized: "active users with order counts"))
        SELECT u.id, u.name, COUNT(o.id) AS orders
        FROM users AS u
        LEFT JOIN orders AS o ON o.user_id = u.id
        WHERE u.active = TRUE
          AND u.created_at >= '2025-01-01'
        GROUP BY u.id, u.name
        HAVING COUNT(o.id) > 3
        ORDER BY orders DESC
        LIMIT 10;
        """#),

        ("php", "PHP", #"""
        <?php
        // \#(String(localized: "user greeting"))
        function greet(string $name, int $count = 1): string {
            $marks = str_repeat('!', $count);
            return "\#(String(localized: "Hello, {$name}{$marks}"))";
        }

        $users = ['Ada', 'Linus', 'Grace'];
        foreach ($users as $i => $user) {
            echo greet($user, $i + 1) . PHP_EOL;
        }
        """#),
    ]
}
