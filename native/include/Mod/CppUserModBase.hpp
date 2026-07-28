#pragma once

// Minimal ABI-compatible declaration for UE4SS 3.0.1 c2ac246.
// The upstream header pulls in the complete optional GUI/Input dependency tree.
// This collector does not use those facilities, but must preserve the base
// class data layout and virtual-function order exactly.

#include <memory>
#include <vector>

#include <Common.hpp>
#include <String/StringType.hpp>

namespace RC
{
    namespace GUI
    {
        class GUITab;
    }

    namespace LuaMadeSimple
    {
        class Lua;
    }

    class CppUserModBase
    {
      protected:
        std::vector<std::shared_ptr<GUI::GUITab>> GUITabs{};

      public:
        StringType ModName{};
        StringType ModVersion{};
        StringType ModDescription{};
        StringType ModAuthors{};
        StringType ModIntendedSDKVersion{};

        RC_UE4SS_API CppUserModBase();
        RC_UE4SS_API virtual ~CppUserModBase();

        RC_UE4SS_API virtual auto on_update() -> void {}
        RC_UE4SS_API virtual auto on_unreal_init() -> void {}
        RC_UE4SS_API virtual auto on_ui_init() -> void {}
        RC_UE4SS_API virtual auto on_program_start() -> void {}

        RC_UE4SS_API virtual auto on_lua_start(
            StringViewType,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            std::vector<LuaMadeSimple::Lua*>&
        ) -> void {}

        RC_UE4SS_API virtual auto on_lua_start(
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            std::vector<LuaMadeSimple::Lua*>&
        ) -> void {}

        RC_UE4SS_API virtual auto on_lua_stop(
            StringViewType,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            std::vector<LuaMadeSimple::Lua*>&
        ) -> void {}

        RC_UE4SS_API virtual auto on_lua_stop(
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            std::vector<LuaMadeSimple::Lua*>&
        ) -> void {}

        RC_UE4SS_API virtual auto on_dll_load(StringViewType) -> void {}
        RC_UE4SS_API virtual auto render_tab() -> void {}

        RC_UE4SS_API virtual auto on_lua_start(
            StringViewType,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua*
        ) -> void {}

        RC_UE4SS_API virtual auto on_lua_start(
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua*
        ) -> void {}

        RC_UE4SS_API virtual auto on_lua_stop(
            StringViewType,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua*
        ) -> void {}

        RC_UE4SS_API virtual auto on_lua_stop(
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua&,
            LuaMadeSimple::Lua*
        ) -> void {}

        RC_UE4SS_API virtual auto on_cpp_mods_loaded() -> void {}
    };
}
