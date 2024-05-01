module ILPErrorCodes {

    public type ILPErrorCode = {
        code : Text;
        name : Text;
        message : Text;
    };

    public let ILP_ERRORS = {
        timedOut = {
            code = "R00";
            name = "Transfer Timed Out";
            message = "The transfer timed out, meaning the next party in the chain did not respond. This could be because you set your timeout too low or because something took longer than it should. The sender MAY try again with a higher expiry, but they SHOULD NOT do this indefinitely or a malicious connector could cause them to tie up their money for an unreasonably long time.";
        };
        invalidPacket = {
            code = "F01";
            name = "Invalid Packet";
            message = "The packet format is invalid.";
        };
        unreachable = {
            code = "F02";
            name = "Unreachable";
            message = "The destination is unreachable.";
        };
        invalidAmount = {
            code = "F03";
            name = "Invalid Amount";
            message = "The amount specified is invalid.";
        };
        insufficientLiquidity = {
            code = "T04";
            name = "Insufficient Liquidity";
            message = "There is not enough liquidity to complete the transfer.";
        };
    };
};
