"""Talent branches for the second round of towers (2026-11-25, the user's picks): Spike Field, Shredder, Elder Drake
in all four trees, the Hoard Keeper only in the Building tree (its T2/T3 nodes unlock every element's tiers).

    python tools/second_round_talents.py            add the branches (refuses if they are there)
    python tools/second_round_talents.py --remove   take them out again (needs the marker comment the script writes;
                                                    the editor drops comments when it re-saves a tree)

The branches keep the old form (tools/new_tower_talents.py): the partner path's entry node (shared), own stat nodes
up to step 3, T2 at step 4, a two-lane fork of three nodes, T3 at step 8 (one-way to the tree's overall capstone,
needs T2), a capstone. Pairs (the user, 2026-11-25): Spike Field with the trap path, Shredder with the Nova path,
Elder Drake with the Bolter path, the Hoard Keeper with the economy path (Spoils). Existing nodes are never moved:
the user places nodes by hand in the editor's Talents screen. The effects are set by tools/second_round_effects.py.
Check the layout with tools/talent_preview.py.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import new_tower_talents as base  # noqa: E402

branch = base.branch
MARK = "second_round_talents"

FIRE = [
    branch("Elder Drake", "hot_bolts",
           [("Ancient Heat", 3, "Fire Elder Drake damage +8%"), ("Long Neck", 2, "Fire Elder Drake range +0.2 tiles")],
           [("Kindled Bite", 3, "Fire Elder Drake ignite chance +5 points"),
            ("Wide Breath", 2, "The Elder Drake's breath line is 3 px wider on each side"),
            ("Smoulder", 3, "Fire Elder Drake burn potency +10%")],
           [("Old Fury", 3, "Fire Elder Drake attack speed +0.03"),
            ("Second Wind", 2, "The breath is ready again 20 s into a wave"),
            ("Scale Glint", 2, "Fire Elder Drake critical chance +4 points")],
           ("Wyrmfire", "The breath reaches 3 tiles farther and its burns last twice as long")),
    branch("Shredder", "blast_furnace",
           [("Searing Rasp", 3, "Fire Shredder damage +8%"), ("Wide Rasp", 2, "Fire Shredder range +0.2 tiles")],
           [("Kindling", 3, "Fire Shredder ignite chance +5 points"),
            ("Melted Plate", 2, "Shredded enemies take 5% more Fire damage for each shred stack"),
            ("Slag", 3, "Fire Shredder burn potency +10%")],
           [("Fast Rasp", 3, "Fire Shredder attack speed +0.04"),
            ("Deep Cuts", 2, "Shred stacks last 1 s longer"),
            ("Hot Iron", 2, "Fire Shredder resistance penetration +5%")],
           ("Meltdown", "Every 4th pulse sets every enemy it hits on fire and strips two shred stacks at once")),
    branch("Spike Field", "hot_snare",
           [("Hot Iron Spikes", 3, "Fire Spike Field damage +8%"), ("Quick Spikes", 3, "Fire Spike Field attack speed +0.04")],
           [("Tinder Floor", 3, "Fire Spike Field ignite chance +5 points"),
            ("Searing Wounds", 2, "Burns from the spikes are 15% stronger"),
            ("Coals", 3, "Fire Spike Field burn potency +10%")],
           [("Barbs", 2, "Fire Spike Field slow +5 points"),
            ("Lingering Heat", 2, "Struck enemies stay slowed 0.5 s longer"),
            ("Hot Points", 2, "Fire Spike Field critical chance +4 points")],
           ("Bed of Coals", "Every enemy on the field takes a burn tick each second, between strikes too")),
]

FROST = [
    branch("Elder Drake", "ice_bolts",
           [("Ancient Frost", 3, "Frost Elder Drake damage +8%"), ("Long Neck", 2, "Frost Elder Drake range +0.2 tiles")],
           [("Rime Bite", 3, "Frost Elder Drake slows last 1 tick longer"),
            ("Wide Breath", 2, "The Elder Drake's breath line is 3 px wider on each side"),
            ("Glacial", 3, "Frost Elder Drake slow potency +10%")],
           [("Old Fury", 3, "Frost Elder Drake attack speed +0.03"),
            ("Second Wind", 2, "The breath is ready again 20 s into a wave"),
            ("Frost Glint", 2, "Frost Elder Drake critical chance +4 points")],
           ("Ice Age", "The breath freezes every enemy it hits for 1.5 s (bosses 0.5 s)")),
    branch("Shredder", "frost_ring",
           [("Frost Rasp", 3, "Frost Shredder damage +8%"), ("Wide Rasp", 2, "Frost Shredder range +0.2 tiles")],
           [("Brittle Plate", 2, "Shredded enemies take 5% more Frost damage for each shred stack"),
            ("Cold Teeth", 3, "Frost Shredder slow potency +10%"),
            ("Deep Cuts", 2, "Shred stacks last 1 s longer")],
           [("Fast Rasp", 3, "Frost Shredder attack speed +0.04"),
            ("Numbing", 3, "Frost Shredder slows last 1 tick longer"),
            ("Cold Iron", 2, "Frost Shredder resistance penetration +5%")],
           ("Shatterpoint", "An enemy with three shred stacks that is frozen takes 30% more damage from every tower")),
    branch("Spike Field", "cold_snare",
           [("Ice Spikes", 3, "Frost Spike Field damage +8%"), ("Quick Spikes", 3, "Frost Spike Field attack speed +0.04")],
           [("Frost Barbs", 2, "Frost Spike Field slow +5 points"),
            ("Black Ice", 3, "Frost Spike Field slow potency +10%"),
            ("Lingering Cold", 2, "Struck enemies stay slowed 0.5 s longer")],
           [("Frozen Points", 2, "Frost Spike Field critical chance +4 points"),
            ("Rime", 3, "Frost Spike Field slows last 1 tick longer"),
            ("Ice Floor", 2, "Turns on a Frost Spike Field pause enemies 0.1 s longer")],
           ("Permafrost", "The first enemy each wave that steps on the field freezes for 2 s")),
]

POISON = [
    branch("Elder Drake", "venom_bolts",
           [("Ancient Venom", 3, "Poison Elder Drake damage +8%"), ("Long Neck", 2, "Poison Elder Drake range +0.2 tiles")],
           [("Venom Bite", 3, "Poison Elder Drake poison chance +5 points"),
            ("Wide Breath", 2, "The Elder Drake's breath line is 3 px wider on each side"),
            ("Old Rot", 3, "Poison Elder Drake poison potency +10%")],
           [("Old Fury", 3, "Poison Elder Drake attack speed +0.03"),
            ("Second Wind", 2, "The breath is ready again 20 s into a wave"),
            ("Deep Fangs", 2, "Poison Elder Drake bites add 1 more poison stack")],
           ("Blight Breath", "The breath leaves a poison cloud along its whole line for 4 s")),
    branch("Shredder", "toxic_burst",
           [("Acid Rasp", 3, "Poison Shredder damage +8%"), ("Wide Rasp", 2, "Poison Shredder range +0.2 tiles")],
           [("Corrode", 2, "Shredded enemies take 5% more Poison damage for each shred stack"),
            ("Caustic", 3, "Poison Shredder poison potency +10%"),
            ("Deep Cuts", 2, "Shred stacks last 1 s longer")],
           [("Fast Rasp", 3, "Poison Shredder attack speed +0.04"),
            ("Seeping", 3, "Poison Shredder poison chance +5 points"),
            ("Acid Iron", 2, "Poison Shredder resistance penetration +5%")],
           ("Dissolve", "Poison stacks on an enemy with three shred stacks tick twice as fast")),
    branch("Spike Field", "venom_snare",
           [("Venom Spikes", 3, "Poison Spike Field damage +8%"), ("Quick Spikes", 3, "Poison Spike Field attack speed +0.04")],
           [("Dripping Tips", 3, "Poison Spike Field poison chance +5 points"),
            ("Festering", 3, "Poison Spike Field poison potency +10%"),
            ("Deep Prick", 2, "Poison Spike Field strikes add 1 more poison stack")],
           [("Barbs", 2, "Poison Spike Field slow +5 points"),
            ("Lingering Sting", 2, "Struck enemies stay slowed 0.5 s longer"),
            ("Venom Points", 2, "Poison Spike Field critical chance +4 points")],
           ("Nest of Vipers", "An enemy that dies on the field leaves a poison cloud for 3 s")),
]

BUILDING = [
    branch("Elder Drake", "hardened_shots",
           [("Ancient Might", 3, "Physical Elder Drake damage +8%"), ("Long Neck", 2, "Physical Elder Drake range +0.2 tiles")],
           [("Old Scales", 3, "Elder Drake health +15%"),
            ("Wide Breath", 2, "The Elder Drake's breath line is 3 px wider on each side"),
            ("Crushing Jaws", 2, "Physical Elder Drake critical multiplier +0.25")],
           [("Old Fury", 3, "Physical Elder Drake attack speed +0.03"),
            ("Second Wind", 2, "The breath is ready again 20 s into a wave"),
            ("Armour Biter", 2, "Physical Elder Drake resistance penetration +5%")],
           ("Elder's Roar", "The breath knocks every enemy it hits 2 cells back (not bosses)"),
           t2_text="Unlocks Physical Elder Drake T2", t3_text="Unlocks Physical Elder Drake T3"),
    branch("Shredder", "hardened_shots",
           [("Iron Rasp", 3, "Physical Shredder damage +8%"), ("Wide Rasp", 2, "Physical Shredder range +0.2 tiles")],
           [("Sawteeth", 2, "Shredded enemies take 5% more Physical damage for each shred stack"),
            ("Deep Cuts", 2, "Shred stacks last 1 s longer"),
            ("Ripping", 2, "Physical Shredder resistance penetration +5%")],
           [("Fast Rasp", 3, "Physical Shredder attack speed +0.04"),
            ("Fourth Stack", 1, "Shred stacks up to 4 times"),
            ("Steel Collar", 3, "Shredder health +15%")],
           ("Flay", "Shredded enemies lose their elite affix's armour: Shielded elites lose their shield at three stacks")),
    branch("Spike Field", "sharp_teeth",
           [("Iron Spikes", 3, "Physical Spike Field damage +8%"), ("Quick Spikes", 3, "Physical Spike Field attack speed +0.04")],
           [("Barbs", 2, "Spike Field slow +5 points"),
            ("Lingering Wounds", 2, "Struck enemies stay slowed 0.5 s longer"),
            ("Serrated", 2, "Physical Spike Field critical chance +4 points")],
           [("Cheap Planks", 2, "Spike Fields cost 1 gold less"),
            ("Sharpened", 2, "Physical Spike Field resistance penetration +5%"),
            ("Bleeding Feet", 2, "Struck enemies bleed for 20% of the hit over 2 s")],
           ("Caltrops", "Spike Fields can be built on the road next to each other: each one adds 5% to the others' damage")),
    branch("Hoard Keeper", "spoils",
           [("Bigger Pile", 2, "The first Hoard Keeper pays +1 gold a wave per rank"),
            ("Gilded Scales", 2, "Hoard Keeper health +25%")],
           [("Coin Counter", 2, "Hoard Keeper upgrades cost 10% less"),
            ("Interest", 2, "Each Keeper pays +1 gold at a cleared wave while you hold 30 gold or more"),
            ("Tithe", 1, "Keepers pay +1 gold at a wave cleared without losing a life")],
           [("Third Purse", 1, "A third Hoard Keeper pays in full"),
            ("Lucky Coin", 2, "Every 3rd cleared wave a Keeper pays +2 gold"),
            ("Hoard Sense", 1, "A Keeper's pay shows above it while you build")],
           ("Dragon's Hoard", "Each Keeper's pay grows by 1 gold for every 4 waves cleared"),
           t2_text="Unlocks Hoard Keeper T2 for every element", t3_text="Unlocks Hoard Keeper T3 for every element"),
]

TREE_DATA = {
    "fire": ("Fire", FIRE, "keep_awakens"),
    "frost": ("Frost", FROST, "absolute_zero"),
    "poison": ("Poison", POISON, "black_venom"),
    "building": ("Physical", BUILDING, "dragons_keep"),
}

# Layout: flame-like trees get new outer columns (x, k as in new_tower_talents.FLAME), Frost new rays between the
# last round's ones. The user moves them into place in the editor.
COLUMNS = {
    "fire": {"Elder Drake": (-18.0, 0.5), "Shredder": (-21.5, 0.5), "Spike Field": (38.5, 0.5)},
    "poison": {"Elder Drake": (-18.0, 0.5), "Shredder": (-21.5, 0.5), "Spike Field": (36.5, 0.5)},
    "building": {"Elder Drake": (-14.0, 1), "Shredder": (-17.5, 1), "Spike Field": (41.0, 1), "Hoard Keeper": (44.5, 1)},
}
FROST_RAYS = {"Elder Drake": (213.75, 6.5), "Shredder": (326.25, 6.5), "Spike Field": (33.75, 6.5)}


def make_nodes(tree_id, existing):
    element, branches, overall = TREE_DATA[tree_id]
    if tree_id == "frost":
        base.FROST_RAYS["rays"].update(FROST_RAYS)
    else:
        base.FLAME[tree_id]["cols"].update(COLUMNS[tree_id])
    place = base.Placer(tree_id)
    text = (base.TREES / f"{tree_id}_tree.tres").read_text(encoding="utf-8")
    import re
    start_id = re.search(r'^start_id = &"(\w+)"', text, re.M)[1]
    old_steps = base.steps_from(start_id, existing)
    new = []
    extra_links = {}
    shade_count = {}

    def add(nid, name, rank, desc, kind, pos, color, links=(), one_way=(), needs=""):
        assert nid not in existing and all(nid != n["id"] for n in new), f"{tree_id}: id {nid} taken"
        new.append(dict(id=nid, name=name, rank=rank, desc=desc, kind=kind, pos=pos, color=color,
                        links=list(links), one_way=list(one_way), needs=needs))

    for br in branches:
        tower = br["tower"]
        ts = base.tower_slug(tower)
        hang = br["hang_from"]
        # the shade index goes on from the branches already hanging there
        taken = sum(1 for other in existing[hang]["links"] if other in existing and old_steps.get(other, 0) > old_steps[hang]
                    and existing[other]["color"] != existing[hang]["color"])
        shade_count[hang] = shade_count.get(hang, taken) + 1
        color = base.shade(existing[hang]["color"], shade_count[hang])
        hang_step = old_steps[hang]
        stats = br["stats"][:3 - hang_step]
        prev = hang
        d = hang_step
        for sname, srank, sdesc in stats:
            sid = f"{ts}_{base.slug(sname)}"
            add(sid, sname, srank, sdesc, base.STAT, place.at(tower, d), color)
            if prev == hang:
                extra_links.setdefault(hang, []).append(sid)
            else:
                base._link_new(new, prev, sid)
            prev = sid
            d += 1
        t2_id = f"{ts}_t2"
        add(t2_id, f"{tower} T2", 1, br["t2_text"] or f"Unlocks {element} {tower} T2", base.EVOLVE, place.at(tower, d), color)
        base._link_new(new, prev, t2_id)
        lane_ends = []
        for lane, side in ((br["a"], -1.0), (br["b"], 1.0)):
            lprev = t2_id
            for i, (lname, lrank, ldesc) in enumerate(lane):
                lid = f"{ts}_{base.slug(lname)}"
                add(lid, lname, lrank, ldesc, base.STAT, place.at(tower, d + 1 + i, side), color)
                base._link_new(new, lprev, lid)
                lprev = lid
            lane_ends.append(lprev)
        t3_id = f"{ts}_t3"
        add(t3_id, f"{tower} T3", 1, br["t3_text"] or f"Unlocks {element} {tower} T3", base.EVOLVE, place.at(tower, d + 4),
            color, one_way=[overall], needs=t2_id)
        for end in lane_ends:
            base._link_new(new, end, t3_id)
        cname, cdesc = br["cap"]
        cap_id = f"{ts}_{base.slug(cname)}"
        add(cap_id, cname, 1, cdesc, base.CAPSTONE, place.at(tower, d + 5), color)
        base._link_new(new, t3_id, cap_id)
    return new, extra_links


def main():
    base.MARK = MARK
    base.make_nodes = make_nodes
    remove = "--remove" in sys.argv
    for tree_id in TREE_DATA:
        (base.remove_tree if remove else base.add_tree)(tree_id)


if __name__ == "__main__":
    main()
