namespace StillTerminal {
    public enum NewTabButtonAction {
        CHOOSE_PROFILE,
        OPEN_RECENT_PROFILE,
        OPEN_DEFAULT_PROFILE;
    }

    public class NewTabButtonPolicy {
        public static NewTabButtonAction action_for_click (
            bool open_default_on_click,
            bool alternate_pressed
        ) {
            if (open_default_on_click) {
                return alternate_pressed
                    ? NewTabButtonAction.CHOOSE_PROFILE
                    : NewTabButtonAction.OPEN_DEFAULT_PROFILE;
            }

            return alternate_pressed
                ? NewTabButtonAction.OPEN_RECENT_PROFILE
                : NewTabButtonAction.CHOOSE_PROFILE;
        }
    }
}
