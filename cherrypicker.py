#!/usr/bin/env python3
##################################################################################
# forked from: https://github.com/GeoZac/android_vendor_unconv
# License: GPLv3
##################################################################################

import sys
from argparse import ArgumentParser

# Spice up the output
from colorama import init, deinit, Fore  # Back, Style
from pygerrit2 import GerritRestAPI
from pyperclip import copy

from xtrasforcherrypicker import BLACKLIST, UPSTREAM, WHITELIST

init(autoreset=False)

DASHES = "=" * 55
STARS = "*" * 55


def show_banner():
    print(Fore.GREEN)
    print(STARS)
    print("               Cherrypick Helper")
    print(STARS)


def check_excludes(args, c_topic):
    # Split excludes into a list so that we can skip multiple topics
    exclusions = list(args.E.split(",") if args.E is not None else "")
    if exclusions is not None and c_topic in exclusions:
        return False

    return True


# Initialise some variables
PROJECTS = {}
TOPICS = []
# Make a copy of the blocked repos so I can modify it if required
BLOCK_LIST = BLACKLIST
# Set of changes which will be skipped in all cases
DNM = [
]


def get_query(url, query):
    rest = GerritRestAPI(url=url, auth=None)
    return rest.get(query)


# Print help and wait for a input
# if args.H is not None:
#     show_help()
def show_help():
    print(" Cherrypicker")
    print("")


def check_upstream(args):
    status = "open" if args.O else "merged"
    if args.C == "ALL":
        projects = UPSTREAM
    else:
        projects = [project for project in UPSTREAM if args.C in project.lower()]

    for upstream_project in projects:
        upstream_numbers = ""
        upstream_addr, upstream_brnch = setup_project(args)
        upstream_project = f"android_{upstream_project}"
        # query = "/q/status:merged branch:lineage-15.1 project:LineageOS/android_{0}".format(project)
        query = f"/changes/?q=project:LineageOS/{upstream_project}%20status:{status}%20branch:{upstream_brnch}"
        upstream_changes = get_query(upstream_addr, query)[:15]
        print(Fore.BLUE, upstream_project)
        for upstream_change in reversed(upstream_changes):
            upstream_number = upstream_change["_number"]
            upstream_subject = upstream_change["subject"]
            if "translation" in upstream_subject:
                continue
            print(Fore.GREEN, upstream_number, Fore.CYAN, upstream_subject, Fore.RED, get_topic(upstream_change))
            upstream_numbers = upstream_numbers + " " + str(upstream_number)
        print(f"repopick -g {upstream_addr} {upstream_numbers} -P {set_path(upstream_project)}")
        input("Continue ?")

    deinit()
    sys.exit(0)


# noinspection PyShadowingNames
def check_mergeable(change):
    try:
        return change["mergeable"]
    except KeyError:
        return False


def get_topic(m_change):
    try:
        return m_change["topic"]
    except KeyError:
        return None


def adjust_for_qcom(change):
    branch = change["branch"]
    name = change["project"]
    if "pn5xx" in branch:
        name = name.replace("opensource_", "opensource_pn5xx_")
        change["project"] = name
        return change
    if "sn100x" in branch:
        name = name.replace("opensource_", "opensource_sn100x_")
        change["project"] = name
        return change
    if "caf" in branch:
        board = branch.split("caf-")[-1]
        name = name.replace("qcom_", f"qcom-caf_{board}_")
        change["project"] = name
        return change
    if "-legacy-um" in branch:
        name = name.replace("sepolicy", "sepolicy-legacy-um")
        change["project"] = name
        return change
    if "-legacy" in branch:
        name = name.replace("sepolicy", "sepolicy-legacy")
        change["project"] = name
        return change
    print("Caught a new one to adjust for path", branch)
    return change


# Nope these only worth picking up
def setup_project(args, verbose=False):
    if args.R == "los":
        msg = "Seems,serious"
        addr = "https://review.lineageos.org"
        base_branch = args.B if args.B is not None else "lineage-21.0"
        # Kill the blocklist if searching LineageOS gerrit
        global BLOCK_LIST
        BLOCK_LIST = []
    elif args.R is not None:
        msg = "Who dis?"
        addr = args.R
        base_branch = args.B
    else:
        msg = "Meh,its just ice cold"
        addr = "https://gerrit.aicp-rom.com"
        base_branch = args.B if args.B is not None else "u14.0"
    if verbose:
        print(Fore.YELLOW, f"\b{msg}")
    if not base_branch:
        print("Need to specify a branch,use -B argument")
        sys.exit(0)

    return addr, base_branch


def set_query(args):
    if args.Q is not None:
        return f"/changes/?q={args.Q}"
    query = "/changes/?q=status:open"
    if args.T is None:
        final_q = query
    else:
        q_topic = f" topic:{args.T}"
        final_q = "".join([query, q_topic])
    if args.D:
        print(final_q)
    return final_q


def get_changes(args):
    gerrit_addr, gerrit_branch = setup_project(args, True)
    query = set_query(args)
    changes = get_query(gerrit_addr, query)
    if args.D:
        print(query)
    total = len(changes)
    if total > 200 and args.S is None:
        print(f"{total} Changes \nBetter to add a start number or streamline search")
        if input("Set it from manifest ?").lower() == "y":
            args.S = set_start(args)
            changes = get_query(gerrit_addr, query)
        else:
            sys.exit(0)

    if not changes:
        print("No changes, try playing with arguments")
        sys.exit(0)
    else:
        print(Fore.LIGHTMAGENTA_EX, f"\b{total} changes")
    return changes, gerrit_branch


def set_path(project_name):
    # Broken cases: external_wpa_supplicant_8

    if "build" in project_name:
        project_name += "_make"

    elif project_name in ["AICP/bionic", "AICP/art"]:
        return project_name.strip("AICP/")

    elif "vendor_lineage" in project_name:
        project_name = "vendor_aicp"
        return project_name.replace("_", "/")

    if "_" not in project_name:
        return "*Manifest Change*"

    if "AICP" in project_name:
        project_path = project_name.split("AICP/")[1]
        project_path = project_path.replace("_", "/")
        return project_path

    project_path = project_name.split("_", 1)[1]
    project_path = project_path.replace("_", "/")
    return project_path


def set_start(args):
    if args.S is not None:
        return args.S
    # platform_manifest gets only changed once in a while
    gerrit_addr, current_branch = setup_project(args)
    full_query = f"/changes/?q=project:AICP/platform_manifest status:merged branch:{current_branch}"
    if "aicp" in gerrit_addr and not args.S:  # Get the last merged important change
        platform_changes = get_query(gerrit_addr, full_query)
        if not platform_changes:
            return 0
        last_patch = platform_changes[5]["_number"]
        last_patch_change = platform_changes[5]["subject"]
        print(Fore.RED, f"\b{last_patch} {last_patch_change} set as start for commit filter\n")
        args.S = last_patch
        return last_patch

    return 0


def append_projects(args, change):
    project = change["project"]
    PROJECTS[project] = {}
    PROJECTS[project]["path"] = set_path(project)
    # AICP can resolve its own paths, so it gets a separate string of repopick numbers
    if args.R is not None:
        PROJECTS[project]["gerrit"] = setup_project(args)[0]
    PROJECTS[project]["numbers"] = [change["_number"]]


def parse_changes(args, changes, gerrit_branch):
    skipped = 0
    merged = False
    total = len(changes)
    digits = len(str(changes[0]["_number"]))
    for index, change in enumerate(reversed(changes)):
        # print(change)
        number = change["_number"]
        subject = change["subject"]
        topic = get_topic(change)
        project = change["project"]
        can_merge = check_mergeable(change)
        if number >= set_start(args) and gerrit_branch in change["branch"]:
            if not any(item in project.lower() for item in BLOCK_LIST) or any(
                    item in project.lower() for item in WHITELIST):
                if gerrit_branch != change["branch"]:
                    change = adjust_for_qcom(change)
                if (change["status"] != "MERGED" or args.D or args.M) and number not in DNM:
                    print(
                        Fore.GREEN, f"\b{str(index + 1).zfill(3)}/{total}",
                        Fore.BLUE, str(number).rjust(digits),
                        Fore.CYAN, str(can_merge).ljust(7),
                        Fore.LIGHTBLUE_EX, subject[:55].ljust(55),
                        Fore.YELLOW, project[-20:].ljust(20), "|",
                        Fore.MAGENTA, topic if topic else ""
                    )
                    if (not check_excludes(args, topic)) or (not can_merge and not args.M):
                        skipped += 1
                        continue
                    if topic not in TOPICS and topic is not None:
                        TOPICS.append(topic)
                    if change["status"] == "MERGED":
                        merged = True
                    if project not in PROJECTS:
                        append_projects(args, change)

                    else:
                        PROJECTS[project]["numbers"].append(number)
            elif args.D:
                print(
                    Fore.RED, f"\b{str(index + 1).zfill(3)}/{total}",
                    Fore.RED, str(number).rjust(digits),
                    Fore.RED, "Ignored",
                    Fore.RED, subject[:55].ljust(55),
                    Fore.RED, project[-20:].ljust(20), "|",
                    Fore.RED, topic if topic else ""
                )
    return skipped, merged


def present_changes(args, skipped, merged):
    to_pick = 0
    cherry_picked = 0
    numbers = ""
    fwb = "AICP/frameworks_base"
    print(DASHES)
    print(Fore.GREEN, f"\b{len(PROJECTS)} projects")
    print(f"Skipping {args.E if args.E is not None else 'None'}")
    print(DASHES)
    for project in PROJECTS:
        change_numbers = PROJECTS[project]["numbers"]
        change_numbers.sort()  # Doesn't seem to work in next line
        count = len(change_numbers)
        print(Fore.YELLOW, "\brepopick", Fore.RED, "\b-g", PROJECTS[project].get("gerrit", "\b" * 4),
              "-f" if merged else "\b", "-P", PROJECTS[project]["path"],
              " ".join(str(x) for x in change_numbers), Fore.CYAN)
        to_pick += len(change_numbers)
        if args.R is None and fwb in project:
            continue
        cherry_picked = count if count > cherry_picked else cherry_picked
        numbers += " ".join(str(x) for x in change_numbers) + " "
    if args.R is None and cherry_picked > 0:
        print(DASHES)
        pick_string = f"repopick {numbers}-c {cherry_picked}"
        print(Fore.CYAN, f"\b{pick_string}")
        copy(pick_string)
        if PROJECTS.get(fwb, None):  # Not all queries may have a change in fwb
            fwb_changes = PROJECTS[fwb]["numbers"]
            print(Fore.CYAN, "\brepopick", " ".join(str(x) for x in fwb_changes), "-c", args.F + len(fwb_changes))
        print(DASHES)
    if TOPICS:
        print(Fore.GREEN, "\brepopick -t", " ".join(item for item in TOPICS if item))
        print(DASHES)
    print(Fore.MAGENTA, f"\b{to_pick} commits to pick")
    print(Fore.BLUE, f"\b{skipped} commits skipped")
    print(DASHES)


def parse_arguments():
    parser = ArgumentParser()

    # All argument goes here
    parser.add_argument("-R", help="Select ROM to cherry pick from", type=str.lower)
    parser.add_argument("-T", help="Topics to pick")
    parser.add_argument("-S", type=int, help="Commit to start searching from")
    parser.add_argument("-B", help="Branch to search for")
    parser.add_argument("-D", action="store_true", help="Debug mode")
    parser.add_argument("-M", action="store_true", default=True, help="Check mergeability")
    parser.add_argument("-C", const="ALL", nargs="?", help="Check upstream for any new changes")
    parser.add_argument("-O", action="store_true", help="Search upstream for open changes")
    parser.add_argument("-Q", help="Query to search for")
    parser.add_argument("-E", help="Exclude topics")
    parser.add_argument("-F", nargs="?", const=1, type=int, default=22, help="No of Commits to check for on fwb")

    # parser.add_argument("-h", help="Show the f***ing help and exit")
    return parser.parse_args()


# Always keep this method above main, for better control
def set_defaults(args):
    assert args is not None


def repo_pick():
    args = parse_arguments()
    set_defaults(args)
    if args.C is not None:
        args.R = "los"
        args.B = None
        check_upstream(args)
    changes, branch = get_changes(args)
    skipped, merged = parse_changes(args, changes, branch)
    present_changes(args, skipped, merged)


if __name__ == "__main__":
    show_banner()
    repo_pick()
