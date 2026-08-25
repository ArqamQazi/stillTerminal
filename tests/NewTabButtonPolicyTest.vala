namespace StillTerminal.Tests {
    private void assert_action (
        StillTerminal.NewTabButtonAction expected,
        bool open_default_on_click,
        bool alternate_pressed
    ) {
        var actual = StillTerminal.NewTabButtonPolicy.action_for_click (
            open_default_on_click,
            alternate_pressed
        );
        assert (actual == expected);
    }

    private void test_classic_click_opens_chooser () {
        assert_action (
            StillTerminal.NewTabButtonAction.CHOOSE_PROFILE,
            false,
            false
        );
    }

    private void test_classic_shift_click_opens_recent_profile () {
        assert_action (
            StillTerminal.NewTabButtonAction.OPEN_RECENT_PROFILE,
            false,
            true
        );
    }

    private void test_quick_click_opens_default_profile () {
        assert_action (
            StillTerminal.NewTabButtonAction.OPEN_DEFAULT_PROFILE,
            true,
            false
        );
    }

    private void test_quick_shift_click_opens_chooser () {
        assert_action (
            StillTerminal.NewTabButtonAction.CHOOSE_PROFILE,
            true,
            true
        );
    }

    public static int main (string[] args) {
        Test.init (ref args);
        Test.add_func (
            "/new-tab-button/classic-click-opens-chooser",
            test_classic_click_opens_chooser
        );
        Test.add_func (
            "/new-tab-button/classic-shift-click-opens-recent-profile",
            test_classic_shift_click_opens_recent_profile
        );
        Test.add_func (
            "/new-tab-button/quick-click-opens-default-profile",
            test_quick_click_opens_default_profile
        );
        Test.add_func (
            "/new-tab-button/quick-shift-click-opens-chooser",
            test_quick_shift_click_opens_chooser
        );
        return Test.run ();
    }
}
