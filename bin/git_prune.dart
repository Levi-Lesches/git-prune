import 'dart:io';

import 'package:args/args.dart';

List<String> getBranches(String pruneOutput) {
  // From: " * [pruned] origin/branch-name", matches "branch-name".
  // Copy-and-paste this into https://regexr.com and use prune-output.txt as a test
  final regex = RegExp(r" \* \[pruned\] \w+\/(.+)");
  return [
    for (final match in regex.allMatches(pruneOutput))
      if (match.groupCount >= 1)
      match.group(1)!,
  ];
}

Future<List<String>> getMissingBranches() async {
  // From: "  branch-name a50afd7 [origin/branch-name: gone] Initial commit", matches "branch-name"
  // Copy-and-paste this into https://regexr.com and use missing-output.txt as a test
  final regex = RegExp(r"\[\w+/(.+): gone\]");
  final result = await Process.run("git", ["branch", "-vv"]);
  if (result.exitCode != 0) {
    print("[Warning] Could not check for missing statuses");
    return [];
  }
  return [
    for (final match in regex.allMatches(result.stdout))
      if (match.groupCount >= 1)
        match.group(1)!,
  ];
}

Future<List<String>> getPrunedBranches(String remote) async {
  final result = await Process.run("git", ["remote", "prune", remote]);
  if (result.exitCode != 0) {
    print("Could not prune $remote. Output: \n${result.stderr}");
    exit(1);  // Error code 1: Could not prune branch
  }

  final pruneOutput = result.stdout.trim();
  if (pruneOutput.isEmpty) {
    print("No branches pruned");
    return [];
  }

  final prunedBranches = getBranches(pruneOutput);
  if (prunedBranches.isEmpty) {
    print("Could not detect branches. Here was the output: \n$pruneOutput");
    exit(2);  // Error code 2: Could not parse prune output
  }

  return prunedBranches;
}

void main(List<String> cliArgs) async {
  final parser = ArgParser();
  parser.addOption("remote", abbr: "r", help: "The remote to prune", defaultsTo: "origin");
  // TODO: PR the --help message
  parser.addFlag("help", abbr: "h", help: "Show this help message", negatable: false);
  // TODO: PR parse(ignoreErrors: true)
  final args = parser.parse(cliArgs);
  final remote = args.option("remote")!;
  final showHelp = args.flag("help");

  print("");

  if (showHelp) {
    print("Usage: git prune [--remote <remote>] [--help]");
    print(parser.usage);
    exit(0);
  }

  final prunedBranches = await getPrunedBranches(remote);
  for (final branch in prunedBranches) {
    final result = await Process.run("git", ["branch", "-D", branch]);
    if (result.stderr.isNotEmpty) print(result.stderr.trim());
    if (result.stdout.isNotEmpty) print(result.stdout.trim());
  }

  final missingBranches = await getMissingBranches();
  for (final branch in missingBranches) {
    print("Branch $branch has a missing upstream. Check if you can safely delete it");
  }
}
