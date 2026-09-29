import Testing
@testable import SmallGame

// #expect can't wrap a mutating call, so each place/breach result is bound first.
struct DefenseRulesTests {
    private typealias Cell = DefenseRules.Cell

    /// Placing is the whole economy: it has to cost exactly the card price
    /// and take the cell, or coins and the board drift apart.
    @Test func placingSpendsCoinsAndTakesTheCell() {
        var board = DefenseRules.Board(rows: 6)
        let placed = board.place(.slingshot, at: Cell(lane: 2, row: 0), now: 0)
        #expect(placed)
        #expect(board.coins == DefenseRules.startingCoins - DefenseRules.Defender.slingshot.cost)
        #expect(board.occupied == [Cell(lane: 2, row: 0)])
    }

    /// Two defenders on one cell, or one off the board, would be invisible
    /// or unreachable — and the coins would be gone anyway.
    @Test func cannotPlaceOnATakenCellOrOffTheBoard() {
        var board = DefenseRules.Board(rows: 6)
        let first = board.place(.piggyBank, at: Cell(lane: 0, row: 0), now: 0)
        let onTop = board.place(.schoolbag, at: Cell(lane: 0, row: 0), now: 0)
        let pastLastLane = board.place(.schoolbag, at: Cell(lane: DefenseRules.lanes, row: 0), now: 0)
        let pastTopRow = board.place(.schoolbag, at: Cell(lane: 0, row: 6), now: 0)
        #expect(first)
        #expect(!onTop && !pastLastLane && !pastTopRow)
        #expect(board.coins == DefenseRules.startingCoins - DefenseRules.Defender.piggyBank.cost)
    }

    /// Recharge is what stops a full purse from walling every lane at once;
    /// it is per card, so other cards stay playable meanwhile.
    @Test func aCardRechargesBeforeItPlaysAgain() {
        var board = DefenseRules.Board(rows: 6)
        board.earn(1000)
        let cooldown = DefenseRules.Defender.schoolbag.cooldown
        let first = board.place(.schoolbag, at: Cell(lane: 0, row: 0), now: 10)
        let tooSoon = board.place(.schoolbag, at: Cell(lane: 1, row: 0), now: 10 + cooldown / 2)
        let otherCard = board.place(.piggyBank, at: Cell(lane: 1, row: 0), now: 10 + cooldown / 2)
        let recharged = board.place(.schoolbag, at: Cell(lane: 2, row: 0), now: 10 + cooldown)
        #expect(first && !tooSoon && otherCard && recharged)
        #expect(abs(board.rechargeLeft(.schoolbag, now: 10 + cooldown * 1.5) - 0.5) < 0.001)
    }

    @Test func cannotPlaceWithoutTheCoins() {
        var board = DefenseRules.Board(rows: 6)
        let slingshot = board.place(.slingshot, at: Cell(lane: 0, row: 0), now: 0)
        let broke = board.place(.firecracker, at: Cell(lane: 1, row: 0), now: 0)
        board.earn(DefenseRules.Defender.firecracker.cost)
        let paid = board.place(.firecracker, at: Cell(lane: 1, row: 0), now: 0)
        #expect(slingshot && !broke && paid)
    }

    /// An eaten defender frees its cell for a replacement.
    @Test func clearingFreesTheCell() {
        var board = DefenseRules.Board(rows: 6)
        let eaten = board.place(.piggyBank, at: Cell(lane: 3, row: 2), now: 0)
        board.clear(Cell(lane: 3, row: 2))
        let replacement = board.place(.slingshot, at: Cell(lane: 3, row: 2), now: 0)
        #expect(eaten && replacement)
    }

    /// Each lane forgives exactly one leak; the next one there loses the
    /// lunch, while untouched lanes keep their slipper.
    @Test func eachLaneSlipperSavesOnce() {
        var board = DefenseRules.Board(rows: 6)
        let firstLeak = board.breach(lane: 2)
        let secondLeak = board.breach(lane: 2)
        let otherLane = board.breach(lane: 0)
        #expect(firstLeak && !secondLeak && otherLane)
        #expect(board.slippers == [1, 3, 4])
    }

    /// The opening must be ants only — the player has barely a slingshot.
    @Test func openingSendsOnlyAnts() {
        for roll in stride(from: 0.0, to: 1.0, by: 0.05) {
            #expect(DefenseRules.bug(roll: roll, elapsed: 44) == .ant)
        }
    }

    /// Late runs mix in every kind, capped so ants still make up the rest.
    @Test func lateRunsMixEveryBug() {
        #expect(DefenseRules.bug(roll: 0, elapsed: 600) == .beetle)
        #expect(DefenseRules.bug(roll: 0.3, elapsed: 600) == .roach)
        #expect(DefenseRules.bug(roll: 0.61, elapsed: 600) == .ant)
    }

    /// Pressure only ever rises, down to a floor that stays playable.
    @Test func pressureRampsToAFloor() {
        for second in stride(from: 1.0, through: 600, by: 1) {
            #expect(DefenseRules.spawnInterval(elapsed: second) <= DefenseRules.spawnInterval(elapsed: second - 1))
            #expect(DefenseRules.spawnInterval(elapsed: second) >= 1.2)
        }
        #expect(DefenseRules.burstSize(wave: 1) == 0)
        #expect(DefenseRules.burstSize(wave: 2) > 0)
        #expect(DefenseRules.burstSize(wave: 100) == 10)
        #expect(DefenseRules.hpScale(wave: 1) == 1)
        #expect(DefenseRules.hpScale(wave: 6) > DefenseRules.hpScale(wave: 5))
    }

    /// The firecracker clears the 3x3 block around it and nothing further.
    @Test func blastCoversTheSurroundingBlock() {
        #expect(DefenseRules.isInBlast(laneOffset: 0, rowOffset: 0))
        #expect(DefenseRules.isInBlast(laneOffset: -1, rowOffset: 1.4))
        #expect(!DefenseRules.isInBlast(laneOffset: 2, rowOffset: 0))
        #expect(!DefenseRules.isInBlast(laneOffset: 0, rowOffset: -1.6))
    }
}
