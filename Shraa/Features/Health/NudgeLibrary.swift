import Foundation

/// Every nudge Shraa can send. Tone: tough, strict, funny.
/// Level 0 = early/mild, 1 = you're behind, 2 = last call.
/// Placeholders: {done} {goal} {left} {steps} {mins} {streak} {amount} {cat} {pct} {daily}
enum NudgeLibrary {

    struct Line { let title: String; let body: String }

    // MARK: Water
    static let water: [[Line]] = [
        [
            Line(title: "Water. Now.", body: "{done} ml so far. Your kidneys filed a complaint. Tap +250 and make it go away."),
            Line(title: "Sip check 💧", body: "Quick 250 ml. Takes 10 seconds. Scrolling takes longer and you do that just fine."),
            Line(title: "Hydration is not optional", body: "You're a software engineer, not a cactus. Drink up."),
            Line(title: "Glass of water?", body: "{left} ml left today. Start chipping away, one glass at a time."),
            Line(title: "Tiny task alert", body: "Stand up. Walk to the bottle. Drink. Congratulations, you're productive."),
        ],
        [
            Line(title: "You're falling behind", body: "{done} ml of {goal}. That's not a water intake, that's a rumour. Drink 500 now."),
            Line(title: "Dehydration speedrun?", body: "You're winning it. Not a game you want to win. {left} ml to go."),
            Line(title: "Headache incoming", body: "That 4 pm headache isn't your code. It's the {left} ml you haven't drunk."),
            Line(title: "Strict mode: ON", body: "No more excuses. One full glass, right now, before you read the next notification."),
            Line(title: "Your skin called", body: "It wants to know why you're ignoring it. {left} ml left. Fix it."),
        ],
        [
            Line(title: "LAST CALL 🚨", body: "{left} ml left and the day is almost done. Two big glasses. Go. Now."),
            Line(title: "This is embarrassing", body: "{done} ml all day. Plants get more water than you. Drink 500 ml right now."),
            Line(title: "Final warning", body: "You set a {goal} ml goal. Past you is disappointed. Present you can still fix it."),
            Line(title: "I'm not mad, just disappointed", body: "OK, I'm a little mad. {left} ml. Bottle. Mouth. Now."),
        ],
    ]

    // MARK: Steps
    static let steps: [[Line]] = [
        [
            Line(title: "Legs still work?", body: "{steps} steps so far. Let's prove they do. A 10-min walk gets you ~1,000."),
            Line(title: "Move it 🚶‍♀️", body: "{left} steps to go. Take your next call walking. Multitasking queen."),
            Line(title: "Chair detected", body: "You've been in a relationship with that chair all day. Take a break. Walk."),
            Line(title: "Step it up", body: "Literally. {left} to go. Stairs count double in my heart."),
        ],
        [
            Line(title: "You're behind. Badly.", body: "{steps} steps. Your phone moved more than you today. {mins} min walk. Now."),
            Line(title: "10k doesn't walk itself", body: "{left} steps left. Put on shoes. Don't negotiate with yourself."),
            Line(title: "Excuse budget: exhausted", body: "Too busy? Too tired? Noted. Still {left} steps. Go."),
            Line(title: "Strict coach here", body: "No dinner until {mins} minutes of walking. OK, dinner allowed. But WALK."),
        ],
        [
            Line(title: "LAST CALL: STEPS 🚨", body: "{left} steps left. A {mins}-min walk and you win the day. Skip it and you don't."),
            Line(title: "Pace the room", body: "Can't go out? Walk circles in your room while watching something. {left} to go."),
            Line(title: "Tomorrow-you is watching", body: "Will they be proud or will they sigh? {left} steps decides it."),
            Line(title: "Final boss: the sofa", body: "Defeat it. {mins} minutes of walking. Go go go."),
        ],
    ]

    // MARK: Gym
    static let gym: [[Line]] = [
        [
            Line(title: "Gym in 45 min", body: "Pack the bag now so future-you can't make excuses. Streak: {streak} 🔥"),
            Line(title: "Heads up, athlete", body: "Gym time is coming. Eat something light, fill the bottle, find the shoes."),
            Line(title: "Prep mode", body: "Gym soon. Don't open YouTube. You know how that ends."),
        ],
        [
            Line(title: "GYM. NOW. 💪", body: "It's time. Not in 10 minutes. Not after this reel. Now."),
            Line(title: "Your dumbbells miss you", body: "They're lonely. Go visit. Streak on the line: {streak} days."),
            Line(title: "No negotiation", body: "You don't have to feel like it. You just have to show up. Go."),
            Line(title: "Lazy check", body: "You said you're lazy. I said I don't care. Shoes on."),
        ],
        [
            Line(title: "Last chance to train 🚨", body: "Still not checked in. 30 minutes counts. A 20-min home workout counts. Zero doesn't."),
            Line(title: "Streak about to die", body: "{streak} days of discipline. You're really going to let a sofa end it?"),
            Line(title: "Final warning", body: "Skip today and tomorrow gets harder. Ask me how I know. Go."),
        ],
    ]

    // MARK: Meals
    static func meal(_ kind: MealKind) -> [Line] {
        switch kind {
        case .breakfast: return [
            Line(title: "Breakfast?", body: "Coffee is not breakfast. Eat something real, then tap Ate it."),
            Line(title: "Fuel up", body: "Skipping breakfast = 11 am Swiggy order. Your wallet and body both say eat now."),
        ]
        case .lunch: return [
            Line(title: "Lunch time 🍛", body: "Step away from the screen. Eat like a human. Log it."),
            Line(title: "Did you eat?", body: "Bugs can wait. Lunch can't. Go eat, then tap Ate it."),
        ]
        case .dinner: return [
            Line(title: "Dinner check", body: "Eat at home and save ₹400 and your stomach. Log it when done."),
            Line(title: "Dinner o'clock", body: "Late dinners wreck sleep. Eat now, scroll later."),
        ]
        case .snack: return []
        }
    }

    // MARK: Money
    static let budgetWarning: [Line] = [
        Line(title: "{cat} at {pct}% 👀", body: "You've used {pct}% of your {cat} budget. Slow down, big spender."),
        Line(title: "Budget alert: {cat}", body: "{pct}% gone. The month isn't. Choose wisely."),
    ]
    static let budgetBlown: [Line] = [
        Line(title: "{cat} budget: BLOWN 💸", body: "Officially over. Every rupee from here is borrowed from your savings goal."),
        Line(title: "Over budget on {cat}", body: "Congratulations, you played yourself. Freeze {cat} for the rest of the month."),
    ]
    static let monthBlown: [Line] = [
        Line(title: "Monthly budget crossed 🚨", body: "You've spent more than you planned this month. Strict mode: only essentials now."),
    ]
    static let bigSpend: [Line] = [
        Line(title: "{amount} just left your account", body: "Big one. Was it planned or was it a vibe? Tag it in Shraa."),
    ]

    // MARK: Daily
    static let morning: [Line] = [
        Line(title: "Rise and grind ☀️", body: "Top 3 today: {tasks}. Safe to spend: {daily}/day. Water bottle: fill it."),
        Line(title: "Morning, boss", body: "Today's mission: {tasks}. Budget: {daily}/day. Steps: 10k. No excuses."),
    ]
    static let evening: [Line] = [
        Line(title: "Scorecard time 📋", body: "Steps, water, gym, tasks. Did you show up today? Tap to see the damage."),
        Line(title: "Day's almost done", body: "Check your scorecard, plan tomorrow's top 3, and sleep on time. Phone down soon."),
    ]

    static func pick(_ lines: [Line], _ values: [String: String]) -> Line {
        let line = lines.randomElement() ?? Line(title: "Shraa", body: "Time to do the thing.")
        return Line(title: fill(line.title, values), body: fill(line.body, values))
    }

    static func fill(_ s: String, _ values: [String: String]) -> String {
        values.reduce(s) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
    }
}
