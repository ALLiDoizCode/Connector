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
            code = "F00";
            name = "Invalid Packet";
            message = "The packet format is invalid.";
        };
        unrecognizedAddress = {
            code = "F01";
            name = "Unrecognized Address";
            message = "The destination address is not recognized.";
        };
        invalidAmount = {
            code = "F02";
            name = "Invalid Amount";
            message = "The amount specified is invalid.";
        };
        insufficientLiquidity = {
            code = "F03";
            name = "Insufficient Liquidity";
            message = "There is not enough liquidity to complete the transfer.";
        };
        rateLimited = {
            code = "F04";
            name = "Rate Limited";
            message = "The transfer is rate limited.";
        };
        unreachable = {
            code = "F05";
            name = "Unreachable";
            message = "The destination is unreachable.";
        };
        invalidFields = {
            code = "F06";
            name = "Invalid Fields";
            message = "One or more fields in the packet are invalid.";
        };
        transferIncomplete = {
            code = "F07";
            name = "Transfer Incomplete";
            message = "The transfer did not complete.";
        };
        unexpectedError = {
            code = "F08";
            name = "Unexpected Error";
            message = "An unexpected error occurred.";
        };
    };
};
