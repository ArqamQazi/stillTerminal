namespace StillTerminal.Tests {
    private void test_multiplexer_profile_type_round_trip () {
        var type = StProfileType.from_string ("multiplexer");
        assert (type != null);
        assert (type == StProfileType.MULTIPLEXER);
        assert_cmpstr (
            type.to_string (),
            CompareOperator.EQ,
            "multiplexer"
        );
    }

    private void test_multiplexer_profile_builds_arguments () {
        var parameters = new Gee.HashMap<string, string> ();
        parameters["multiplexer"] = "zellij";
        parameters["session"] = "work";
        var profile = new StProfile (
            "mux",
            "Multiplexer",
            "system",
            Environment.get_home_dir (),
            null,
            null,
            null,
            StProfileType.MULTIPLEXER,
            parameters,
            "Terminal Multiplexer"
        );

        string[] args = profile.get_multiplexer_arguments ();
        assert (args != null);
        assert (args.length == 4);
        assert_cmpstr (args[0], CompareOperator.EQ, "zellij");
        assert_cmpstr (args[1], CompareOperator.EQ, "attach");
        assert_cmpstr (args[2], CompareOperator.EQ, "--create");
        assert_cmpstr (args[3], CompareOperator.EQ, "work");
    }

    public static int main (string[] args) {
        Test.init (ref args);
        Test.add_func (
            "/multiplexer-profile/type-round-trip",
            test_multiplexer_profile_type_round_trip
        );
        Test.add_func (
            "/multiplexer-profile/builds-arguments",
            test_multiplexer_profile_builds_arguments
        );
        return Test.run ();
    }
}
