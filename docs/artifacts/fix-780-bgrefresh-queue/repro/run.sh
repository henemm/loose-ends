#!/bin/bash
cd "$(dirname "$0")" || exit 1
clang -fobjc-arc -c FakeScheduler.m -o FakeScheduler.o || exit 1
swiftc -swift-version 6 -import-objc-header FakeScheduler.h main.swift FakeScheduler.o -o repro 2>&1 | grep -E "error" | head -5
echo "--- using: nil (wie im App-Code)"
./repro nil; echo "exit=$?"
echo "--- using: .main"
./repro main; echo "exit=$?"
echo "--- using: nil, Closure @Sendable"
./repro sendable; echo "exit=$?"
