import 'dart:io';

import 'package:args/args.dart';

Future<String?> prune(String remote) async {
  final result = await Process.run("git", ["remote", "prune", remote]);
  if (result.exitCode != 0) return null;
  return result.stdout;
}

// Future<String?> prune(String remote) async {
//   return File("output.txt").readAsString();
// }

List<String> getBranches(String pruneOutput) {
  // From: " * [pruned] origin/branch-name", matches "branch-name".
  // Copy-and-paste this into https://regexr.com and use output.txt as a test
  final regex = RegExp(r" \* \[pruned\] \w+\/(.+)");
  final matches = regex.allMatches(pruneOutput);
  return [
    for (final match in matches)
      if (match.groupCount >= 1)
      match.group(1)!,
  ];
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

  if (showHelp) {
    print("Usage: git prune [--remote <remote>] [--help]");
    print(parser.usage);
    exit(0);
  }

  final pruneOutput = await prune(remote);
  if (pruneOutput == null) {
    print("Could not prune $remote");
    exit(1);  // Error code 1: Could not prune branch
  }

  final branches = getBranches(pruneOutput);
  if (branches.isEmpty) {
    print("Could not detect branches. Here was the output: \n$pruneOutput");
    exit(2);  // Error code 2: Could not parse prune output
  }

  for (final branch in branches) {
    final result = await Process.run("git", ["branch", "-D", branch]);
    if (result.stderr.isNotEmpty) print(result.stderr.trim());
    if (result.stdout.isNotEmpty) print(result.stdout.trim());
  }
}
