import SwiftUI

// Color extension for persistence
extension Color {
    func toHex() -> String {
        // Convert SwiftUI Color to UIColor safely
        let uiColor = UIColor(self)

        // Get RGBA components
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        // Try to get components - if it fails, use default black
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#000000"
        }

        // Convert to hex string (RGB only, ignoring alpha)
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (ignore alpha, use first 6 digits for RGB)
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0
        )
    }
}

struct ContentView: View {
    let dotSize: CGFloat = 4
    let spriteSize: CGFloat = 20
    let blockSize: CGFloat = 15
    let monsterSize: CGFloat = 18

    // Persisted settings
    @AppStorage("dotSpacing") private var dotSpacing: Double = 30
    @AppStorage("numberOfBlocks") private var numberOfBlocks: Int = 10
    @AppStorage("numberOfMonsters") private var numberOfMonsters: Int = 5
    @AppStorage("gridBackgroundColorHex") private var gridBackgroundColorHex: String = "#000000"
    @AppStorage("gridDotColorHex") private var gridDotColorHex: String = "#FFFFFF"
    @AppStorage("spriteNormalColorHex") private var spriteNormalColorHex: String = "#00FF00"
    @AppStorage("blockColorHex") private var blockColorHex: String = "#FF0000"
    @AppStorage("monsterColorHex") private var monsterColorHex: String = "#FF00FF"
    @AppStorage("controlPanelBackgroundColorHex") private var controlPanelBackgroundColorHex: String = "#2C2C2E"
    @AppStorage("controlPanelTextColorHex") private var controlPanelTextColorHex: String = "#FFFFFF"

    // Game state (non-persisted)
    @State private var spritePosition: CGPoint = CGPoint(x: 30, y: 30)
    @State private var previousPosition: CGPoint = CGPoint(x: 30, y: 30)
    @State private var blockPositions: [CGPoint] = []
    @State private var monsterPositions: [CGPoint] = []
    @State private var lives: Int = 3
    @State private var score: Int = 0
    @State private var isGameOver: Bool = false
    @State private var hasWon: Bool = false
    @State private var spriteColor: Color = .green
    @State private var gridSize: CGSize = .zero
    @State private var showingPreferences: Bool = false

    // Computed color properties
    private var gridBackgroundColor: Color { Color(hex: gridBackgroundColorHex) }
    private var gridDotColor: Color { Color(hex: gridDotColorHex) }
    private var spriteNormalColor: Color { Color(hex: spriteNormalColorHex) }
    private var blockColor: Color { Color(hex: blockColorHex) }
    private var monsterColor: Color { Color(hex: monsterColorHex) }
    private var controlPanelBackgroundColor: Color { Color(hex: controlPanelBackgroundColorHex) }
    private var controlPanelTextColor: Color { Color(hex: controlPanelTextColorHex) }

    // Computed property to check if blast button should be enabled
    private var hasAdjacentEnemies: Bool {
        let adjacentPositions = getAdjacentPositions()
        for adjPos in adjacentPositions {
            if blockPositions.contains(adjPos) || monsterPositions.contains(adjPos) {
                return true
            }
        }
        return false
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Game Board Area
                ZStack {
                    gridBackgroundColor

                    Canvas { context, size in
                        let columns = Int(size.width / dotSpacing)
                        let rows = Int(size.height / dotSpacing)

                        // Draw grid dots
                        for row in 0...rows {
                            for col in 0...columns {
                                let x = CGFloat(col) * dotSpacing
                                let y = CGFloat(row) * dotSpacing

                                let rect = CGRect(
                                    x: x - dotSize / 2,
                                    y: y - dotSize / 2,
                                    width: dotSize,
                                    height: dotSize
                                )

                                context.fill(
                                    Path(ellipseIn: rect),
                                    with: .color(gridDotColor)
                                )
                            }
                        }

                        // Draw blocks
                        for blockPos in blockPositions {
                            let blockRect = CGRect(
                                x: blockPos.x - blockSize / 2,
                                y: blockPos.y - blockSize / 2,
                                width: blockSize,
                                height: blockSize
                            )

                            context.fill(
                                Path(roundedRect: blockRect, cornerRadius: 3),
                                with: .color(blockColor)
                            )
                        }

                        // Draw monsters (as triangles)
                        for monsterPos in monsterPositions {
                            var path = Path()
                            let halfSize = monsterSize / 2
                            // Triangle pointing up
                            path.move(to: CGPoint(x: monsterPos.x, y: monsterPos.y - halfSize))
                            path.addLine(to: CGPoint(x: monsterPos.x - halfSize, y: monsterPos.y + halfSize))
                            path.addLine(to: CGPoint(x: monsterPos.x + halfSize, y: monsterPos.y + halfSize))
                            path.closeSubpath()

                            context.fill(path, with: .color(monsterColor))
                        }

                        // Draw sprite
                        let spriteRect = CGRect(
                            x: spritePosition.x - spriteSize / 2,
                            y: spritePosition.y - spriteSize / 2,
                            width: spriteSize,
                            height: spriteSize
                        )

                        context.fill(
                            Path(ellipseIn: spriteRect),
                            with: .color(spriteColor)
                        )
                    }
                    .onTapGesture { location in
                        if !isGameOver && !hasWon {
                            handleTap(at: location, size: CGSize(width: geometry.size.width, height: geometry.size.height - 80))
                        }
                    }

                    // Game Over / Win overlay
                    if isGameOver {
                        VStack {
                            Text("GAME OVER")
                                .font(.system(size: 60, weight: .bold))
                                .foregroundColor(.red)
                                .padding()

                            Button("Restart") {
                                resetGame(size: geometry.size)
                            }
                            .font(.title2)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    } else if hasWon {
                        VStack {
                            Text("YOU WIN!")
                                .font(.system(size: 60, weight: .bold))
                                .foregroundColor(.green)
                                .padding()

                            Button("Play Again") {
                                resetGame(size: geometry.size)
                            }
                            .font(.title2)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }

                // Control Panel at Bottom
                HStack {
                    // Status Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lives: \(lives)  Score: \(score)")
                            .font(.headline)
                            .foregroundColor(controlPanelTextColor)
                        Text("Blocks: \(blockPositions.count)  Monsters: \(monsterPositions.count)")
                            .font(.headline)
                            .foregroundColor(controlPanelTextColor)
                    }
                    .padding(.leading)

                    Spacer()

                    // Preferences Button
                    Button(action: {
                        showingPreferences = true
                    }) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundColor(controlPanelTextColor)
                            .padding(10)
                    }

                    // Blast Button
                    Button(action: {
                        useBlaster()
                    }) {
                        Text("BLAST")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.trailing)
                    .disabled(isGameOver || hasWon || !hasAdjacentEnemies)
                    .opacity((isGameOver || hasWon || !hasAdjacentEnemies) ? 0.5 : 1.0)
                }
                .frame(height: 80)
                .background(controlPanelBackgroundColor)
            }
            .ignoresSafeArea(.all, edges: .bottom)
            .sheet(isPresented: $showingPreferences) {
                PreferencesView(
                    dotSpacing: $dotSpacing,
                    numberOfBlocks: $numberOfBlocks,
                    gridBackgroundColorHex: $gridBackgroundColorHex,
                    gridDotColorHex: $gridDotColorHex,
                    spriteNormalColorHex: $spriteNormalColorHex,
                    blockColorHex: $blockColorHex,
                    controlPanelBackgroundColorHex: $controlPanelBackgroundColorHex,
                    controlPanelTextColorHex: $controlPanelTextColorHex,
                    onApply: { size in
                        resetGame(size: size)
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                gridSize = geometry.size
                generateBlocks(size: geometry.size)
                generateMonsters(size: geometry.size)
            }
        }
    }

    private func generateBlocks(size: CGSize) {
        let columns = Int(size.width / dotSpacing)
        let rows = Int(size.height / dotSpacing)

        var blocks: [CGPoint] = []
        var attempts = 0
        let maxAttempts = numberOfBlocks * 10

        while blocks.count < numberOfBlocks && attempts < maxAttempts {
            let randomCol = Int.random(in: 1...columns)
            let randomRow = Int.random(in: 1...rows)

            let blockPos = CGPoint(
                x: CGFloat(randomCol) * dotSpacing,
                y: CGFloat(randomRow) * dotSpacing
            )

            // Don't place block on starting position
            if blockPos != spritePosition && !blocks.contains(blockPos) {
                blocks.append(blockPos)
            }
            attempts += 1
        }

        blockPositions = blocks
    }

    private func generateMonsters(size: CGSize) {
        let columns = Int(size.width / dotSpacing)
        let rows = Int(size.height / dotSpacing)

        var monsters: [CGPoint] = []
        var attempts = 0
        let maxAttempts = numberOfMonsters * 10

        while monsters.count < numberOfMonsters && attempts < maxAttempts {
            let randomCol = Int.random(in: 1...columns)
            let randomRow = Int.random(in: 1...rows)

            let monsterPos = CGPoint(
                x: CGFloat(randomCol) * dotSpacing,
                y: CGFloat(randomRow) * dotSpacing
            )

            // Don't place monster on sprite, blocks, or other monsters
            if monsterPos != spritePosition &&
               !blockPositions.contains(monsterPos) &&
               !monsters.contains(monsterPos) {
                monsters.append(monsterPos)
            }
            attempts += 1
        }

        monsterPositions = monsters
    }

    private func spawnMonster(size: CGSize) {
        let columns = Int(size.width / dotSpacing)
        let rows = Int(size.height / dotSpacing)

        var attempts = 0
        let maxAttempts = 100

        while attempts < maxAttempts {
            let randomCol = Int.random(in: 1...columns)
            let randomRow = Int.random(in: 1...rows)

            let monsterPos = CGPoint(
                x: CGFloat(randomCol) * dotSpacing,
                y: CGFloat(randomRow) * dotSpacing
            )

            // Don't place monster on sprite, blocks, or other monsters
            if monsterPos != spritePosition &&
               !blockPositions.contains(monsterPos) &&
               !monsterPositions.contains(monsterPos) {
                monsterPositions.append(monsterPos)
                return
            }
            attempts += 1
        }
    }

    private func getGridPointsAlongPath(from start: CGPoint, to end: CGPoint) -> [CGPoint] {
        // Convert positions to grid coordinates
        let startCol = Int(round(start.x / dotSpacing))
        let startRow = Int(round(start.y / dotSpacing))
        let endCol = Int(round(end.x / dotSpacing))
        let endRow = Int(round(end.y / dotSpacing))

        var points: [CGPoint] = []

        // Bresenham's line algorithm for grid traversal
        let deltaCol = abs(endCol - startCol)
        let deltaRow = abs(endRow - startRow)
        let stepCol = startCol < endCol ? 1 : -1
        let stepRow = startRow < endRow ? 1 : -1

        var error = deltaCol - deltaRow
        var currentCol = startCol
        var currentRow = startRow

        while true {
            // Add current grid point
            let gridPoint = CGPoint(
                x: CGFloat(currentCol) * dotSpacing,
                y: CGFloat(currentRow) * dotSpacing
            )
            points.append(gridPoint)

            // Check if we've reached the end
            if currentCol == endCol && currentRow == endRow {
                break
            }

            let error2 = error * 2

            if error2 > -deltaRow {
                error -= deltaRow
                currentCol += stepCol
            }

            if error2 < deltaCol {
                error += deltaCol
                currentRow += stepRow
            }
        }

        return points
    }

    private func handleTap(at location: CGPoint, size: CGSize) {
        // Find nearest grid point
        let col = round(location.x / dotSpacing)
        let row = round(location.y / dotSpacing)

        let targetX = col * dotSpacing
        let targetY = row * dotSpacing
        let targetPosition = CGPoint(x: targetX, y: targetY)

        // Get all grid points along the path
        let pathPoints = getGridPointsAlongPath(from: spritePosition, to: targetPosition)

        // Check if any point along the path has a block or monster (excluding starting position)
        var hasCollision = false
        for point in pathPoints.dropFirst() {
            if blockPositions.contains(point) || monsterPositions.contains(point) {
                hasCollision = true
                break
            }
        }

        if hasCollision {
            // Collision! Stay at current position and lose a life
            // Just change color to red to indicate collision
            withAnimation {
                spriteColor = .red
            }

            lives -= 1

            // Reset color back to normal after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    spriteColor = spriteNormalColor
                }
            }

            // Check for game over
            if lives <= 0 {
                isGameOver = true
            }
        } else {
            // Normal move
            previousPosition = spritePosition

            // Animate sprite to new position
            withAnimation(.linear(duration: 0.3)) {
                spritePosition = targetPosition
            }

            // Check if monster is adjacent after move (instant death!)
            let adjacentPositions = getAdjacentPositions()
            var monsterAdjacent = false
            for adjPos in adjacentPositions {
                if monsterPositions.contains(adjPos) {
                    monsterAdjacent = true
                    break
                }
            }

            if monsterAdjacent {
                // Monster adjacent! Instant death
                withAnimation {
                    spriteColor = .red
                }

                lives -= 1

                // Reset color back to normal after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        spriteColor = spriteNormalColor
                    }
                }

                // Check for game over
                if lives <= 0 {
                    isGameOver = true
                }
            } else {
                // Sprite survived the move, now monsters move (turn-based)
                moveMonsters()
            }
        }
    }

    private func moveMonsters() {
        var newMonsterPositions: [CGPoint] = []

        for monsterPos in monsterPositions {
            // Calculate direction to sprite
            let dx = spritePosition.x - monsterPos.x
            let dy = spritePosition.y - monsterPos.y

            var newX = monsterPos.x
            var newY = monsterPos.y

            // Move one grid space towards sprite
            if abs(dx) > abs(dy) {
                // Move horizontally
                if dx > 0 {
                    newX += dotSpacing
                } else if dx < 0 {
                    newX -= dotSpacing
                }
            } else if abs(dy) > 0 {
                // Move vertically
                if dy > 0 {
                    newY += dotSpacing
                } else if dy < 0 {
                    newY -= dotSpacing
                }
            }

            let newMonsterPos = CGPoint(x: newX, y: newY)

            // Check if monster moved into sprite
            if newMonsterPos == spritePosition {
                // Sprite dies!
                withAnimation {
                    spriteColor = .red
                }

                lives -= 1

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        spriteColor = spriteNormalColor
                    }
                }

                if lives <= 0 {
                    isGameOver = true
                }

                // Monster stays at new position
                newMonsterPositions.append(newMonsterPos)
            } else {
                // Check if monster moved into a block
                if let blockIndex = blockPositions.firstIndex(of: newMonsterPos) {
                    // Block is destroyed!
                    blockPositions.remove(at: blockIndex)
                }

                // Monster moves to new position
                newMonsterPositions.append(newMonsterPos)
            }
        }

        monsterPositions = newMonsterPositions
    }

    private func getAdjacentPositions() -> [CGPoint] {
        // Get all 8 adjacent positions (including diagonals)
        return [
            CGPoint(x: spritePosition.x, y: spritePosition.y - dotSpacing),                    // Up
            CGPoint(x: spritePosition.x, y: spritePosition.y + dotSpacing),                    // Down
            CGPoint(x: spritePosition.x - dotSpacing, y: spritePosition.y),                    // Left
            CGPoint(x: spritePosition.x + dotSpacing, y: spritePosition.y),                    // Right
            CGPoint(x: spritePosition.x - dotSpacing, y: spritePosition.y - dotSpacing),       // Up-Left
            CGPoint(x: spritePosition.x + dotSpacing, y: spritePosition.y - dotSpacing),       // Up-Right
            CGPoint(x: spritePosition.x - dotSpacing, y: spritePosition.y + dotSpacing),       // Down-Left
            CGPoint(x: spritePosition.x + dotSpacing, y: spritePosition.y + dotSpacing)        // Down-Right
        ]
    }

    private func useBlaster() {
        let adjacentPositions = getAdjacentPositions()

        // Find all adjacent blocks and monsters
        var adjacentBlocks: [CGPoint] = []
        var adjacentMonsters: [CGPoint] = []

        for adjPos in adjacentPositions {
            if blockPositions.contains(adjPos) {
                adjacentBlocks.append(adjPos)
            }
            if monsterPositions.contains(adjPos) {
                adjacentMonsters.append(adjPos)
            }
        }

        let totalEnemies = adjacentBlocks.count + adjacentMonsters.count

        if totalEnemies == 0 {
            // Nothing to blast
            return
        }

        var killedMonster = false

        if totalEnemies == 1 {
            // Blast the single enemy automatically
            if let blockPos = adjacentBlocks.first {
                if let index = blockPositions.firstIndex(of: blockPos) {
                    blockPositions.remove(at: index)
                    score += 1
                }
            } else if let monsterPos = adjacentMonsters.first {
                if let index = monsterPositions.firstIndex(of: monsterPos) {
                    monsterPositions.remove(at: index)
                    score += 1
                    killedMonster = true
                }
            }
        } else {
            // Multiple enemies - blast the first one found
            if let blockPos = adjacentBlocks.first {
                if let index = blockPositions.firstIndex(of: blockPos) {
                    blockPositions.remove(at: index)
                    score += 1
                }
            } else if let monsterPos = adjacentMonsters.first {
                if let index = monsterPositions.firstIndex(of: monsterPos) {
                    monsterPositions.remove(at: index)
                    score += 1
                    killedMonster = true
                }
            }
        }

        // Visual feedback
        withAnimation {
            spriteColor = .yellow
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                spriteColor = spriteNormalColor
            }
        }

        // Spawn new monster(s) if a monster was killed
        if killedMonster {
            let monstersToSpawn = score >= 50 ? 2 : 1
            for _ in 0..<monstersToSpawn {
                spawnMonster(size: gridSize)
            }
        }

        // Check for win condition (all blocks destroyed - monsters respawn infinitely)
        if blockPositions.isEmpty {
            hasWon = true
        }
    }

    private func resetGame(size: CGSize) {
        lives = 3
        score = 0
        isGameOver = false
        hasWon = false
        spritePosition = CGPoint(x: 30, y: 30)
        previousPosition = CGPoint(x: 30, y: 30)
        spriteColor = spriteNormalColor
        blockPositions = []
        monsterPositions = []
        generateBlocks(size: size)
        generateMonsters(size: size)
    }
}

struct PreferencesView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var dotSpacing: Double
    @Binding var numberOfBlocks: Int
    @Binding var gridBackgroundColorHex: String
    @Binding var gridDotColorHex: String
    @Binding var spriteNormalColorHex: String
    @Binding var blockColorHex: String
    @Binding var controlPanelBackgroundColorHex: String
    @Binding var controlPanelTextColorHex: String
    var onApply: (CGSize) -> Void

    @State private var tempDotSpacing: Double
    @State private var tempNumberOfBlocks: Int
    @State private var tempGridBackgroundColor: Color
    @State private var tempGridDotColor: Color
    @State private var tempSpriteNormalColor: Color
    @State private var tempBlockColor: Color
    @State private var tempControlPanelBackgroundColor: Color
    @State private var tempControlPanelTextColor: Color

    init(dotSpacing: Binding<Double>, numberOfBlocks: Binding<Int>, gridBackgroundColorHex: Binding<String>, gridDotColorHex: Binding<String>, spriteNormalColorHex: Binding<String>, blockColorHex: Binding<String>, controlPanelBackgroundColorHex: Binding<String>, controlPanelTextColorHex: Binding<String>, onApply: @escaping (CGSize) -> Void) {
        self._dotSpacing = dotSpacing
        self._numberOfBlocks = numberOfBlocks
        self._gridBackgroundColorHex = gridBackgroundColorHex
        self._gridDotColorHex = gridDotColorHex
        self._spriteNormalColorHex = spriteNormalColorHex
        self._blockColorHex = blockColorHex
        self._controlPanelBackgroundColorHex = controlPanelBackgroundColorHex
        self._controlPanelTextColorHex = controlPanelTextColorHex
        self.onApply = onApply
        self._tempDotSpacing = State(initialValue: dotSpacing.wrappedValue)
        self._tempNumberOfBlocks = State(initialValue: numberOfBlocks.wrappedValue)
        self._tempGridBackgroundColor = State(initialValue: Color(hex: gridBackgroundColorHex.wrappedValue))
        self._tempGridDotColor = State(initialValue: Color(hex: gridDotColorHex.wrappedValue))
        self._tempSpriteNormalColor = State(initialValue: Color(hex: spriteNormalColorHex.wrappedValue))
        self._tempBlockColor = State(initialValue: Color(hex: blockColorHex.wrappedValue))
        self._tempControlPanelBackgroundColor = State(initialValue: Color(hex: controlPanelBackgroundColorHex.wrappedValue))
        self._tempControlPanelTextColor = State(initialValue: Color(hex: controlPanelTextColorHex.wrappedValue))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Game Settings")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Grid Spacing: \(Int(tempDotSpacing)) points")
                            .font(.headline)
                        Slider(value: $tempDotSpacing, in: 20...50, step: 5)
                        Text("Smaller spacing = more dots, tighter grid")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of Blocks: \(tempNumberOfBlocks)")
                            .font(.headline)
                        Slider(value: Binding(
                            get: { Double(tempNumberOfBlocks) },
                            set: { tempNumberOfBlocks = Int($0) }
                        ), in: 5...20, step: 1)
                        Text("More blocks = harder difficulty")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }

                Section(header: Text("Grid Colors")) {
                    ColorPicker("Background Color", selection: $tempGridBackgroundColor)
                    ColorPicker("Dot Color", selection: $tempGridDotColor)
                    ColorPicker("Sprite Color", selection: $tempSpriteNormalColor)
                    ColorPicker("Block Color", selection: $tempBlockColor)
                }

                Section(header: Text("Control Panel Colors")) {
                    ColorPicker("Background Color", selection: $tempControlPanelBackgroundColor)
                    ColorPicker("Text Color", selection: $tempControlPanelTextColor)
                }
            }
            .scrollContentBackground(.visible)
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dotSpacing = tempDotSpacing
                        numberOfBlocks = tempNumberOfBlocks
                        gridBackgroundColorHex = tempGridBackgroundColor.toHex()
                        gridDotColorHex = tempGridDotColor.toHex()
                        spriteNormalColorHex = tempSpriteNormalColor.toHex()
                        blockColorHex = tempBlockColor.toHex()
                        controlPanelBackgroundColorHex = tempControlPanelBackgroundColor.toHex()
                        controlPanelTextColorHex = tempControlPanelTextColor.toHex()
                        onApply(CGSize(width: 400, height: 800))
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
