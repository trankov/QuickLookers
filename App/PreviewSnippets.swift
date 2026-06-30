import Foundation

/// Показательные сниппеты для живого превью темы. Порядок = порядок сегментов.
/// Каждый несёт строки, числа, комментарии, ключевые слова — чтобы тема «играла».
enum PreviewSnippets {
    static let all: [(id: String, name: String, code: String)] = [
        ("swift", "Swift", #"""
        import Foundation

        struct Point: Equatable {            // модель точки
            let x, y: Double
            func distance(to p: Point) -> Double {
                let dx = x - p.x, dy = y - p.y
                return (dx * dx + dy * dy).squareRoot()
            }
        }

        let origin = Point(x: 0, y: 0)
        let target = Point(x: 3, y: 4)
        print("distance = \(origin.distance(to: target))")  // 5.0
        """#),

        ("javascript", "JS", #"""
        // подсчёт слов в строке
        function wordCount(text) {
          const words = text.trim().split(/\s+/);
          return words.filter(Boolean).length;
        }

        const sample = `hello   world
        from quicklookers`;
        console.log(`words: ${wordCount(sample)}`); // words: 3
        """#),

        ("typescript", "TS", #"""
        interface User {
          id: number;
          name: string;
          roles: readonly string[];
        }

        function greet(u: User): string {
          const isAdmin = u.roles.includes("admin");
          return `Hi ${u.name}${isAdmin ? " (admin)" : ""}`;
        }

        const u: User = { id: 1, name: "Ada", roles: ["admin"] };
        console.log(greet(u));
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
            <title>Превью</title>
          </head>
          <body>
            <h1 class="title">Привет, мир</h1>
            <!-- кнопка действия -->
            <button data-id="42" onclick="run()">Запустить</button>
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
    ]
}
