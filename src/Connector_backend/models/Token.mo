module {
 
    public type Token = {
        symbol:Text;
        chain:Chain;
    };

    public type Chain = {
        #BTC:Text;
        #ETH:Text;
        #ICP:Text;
        #SOL:Text;
    };
};