import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Error "mo:base/Error";

import IC "../models/IC";

module {

    private type CanisterId = IC.canister_id;
    private type CanisterStatus = IC.canister_status_response;

    public class CanisterUtils() {

        private let ic : IC.Self = actor "aaaaa-aa";

        public func deleteCanister(canisterId: ?CanisterId): async() {
            switch (canisterId) {
                case (?canisterId) {
                    let bucket = actor(Principal.toText(canisterId)): actor { transferFreezingThresholdCycles: () -> async () };

                    await bucket.transferFreezingThresholdCycles();

                    await ic.stop_canister({ canister_id = canisterId });

                    await ic.delete_canister({ canister_id = canisterId });
                };
                case null {};
            }
        };

        public func stopAndStartCanister(canisterId: Principal): async () {
            await ic.stop_canister({ canister_id = canisterId });
            await ic.start_canister({ canister_id = canisterId });
        };

        public func updateSettings(canisterId: Principal, manager: Principal): async () {
            let controllers: ?[Principal] = ?[canisterId, manager];
            await ic.update_settings(({canister_id = canisterId; settings = {
                controllers = controllers;
                freezing_threshold = null;
                memory_allocation = null;
                compute_allocation = null;
            }}));
        };

        public func installCode(canisterId: Principal, arg: Blob, wasmModule: Blob): async() {
            await ic.install_code({
                arg = arg;
                wasm_module = wasmModule;
                mode = #upgrade;
                canister_id = canisterId;
            });
        };

        public func canisterStatus(canisterId: CanisterId): async CanisterStatus {
            await ic.canister_status({ canister_id = canisterId });
        };

    }
}