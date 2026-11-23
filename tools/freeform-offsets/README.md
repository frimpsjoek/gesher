# freeform-offsets

Static, read-only tools used to port `verifiedBuilds` to a new Freeform build.
Needs `pip install capstone lief`, the new `Freeform` arm64e slice (`lipo -thin arm64e`),
and the reference 5.0 binary (UUID F65BAD7D-…, from the macOS 27.0 OTA payloadv2 chunk with
`aa extract -include-regex 'Freeform\.app/Contents/MacOS/Freeform$'`).

- `macho.py NEW` — resolves the 7 string anchors.
- `fpmatch.py OLD NEW` — masked-instruction fingerprints of every known 5.0 offset.
- `swiftmeta.py BIN CLASS…` — Swift class vtables (allocInitBoard = CRLBoard init slot → b-chain;
  commit = CRLTransactionContext vtable byte 0x2f8).
- Type accessors = `AccessFunction` of the `CRLBoardCRDTData` / `CRLBoardInsertStyleData` descriptors.
- `mergeDatabaseChanges` = unique xref of `mergeDatabaseChanges(_:transaction:squelchLogs:undoable:)`.
- insertStyleCopyHelper = unique raw-identical 24-instruction outlined copy.
