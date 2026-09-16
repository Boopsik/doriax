// (c) Eduardo Doria and contributors
// SPDX-License-Identifier: MIT

#pragma once

#include "Project.h"

#include "yaml-cpp/yaml.h"

#include <filesystem>
#include <map>
#include <string>
#include <vector>

namespace doriax::editor {

// One developer's view of a project: open tabs and their order, each scene's viewport
// camera and guides, and the terrain brush. None of it describes the game, so keeping
// it in project.yaml means a diff every time anyone opens the editor and a conflict
// every time two people do. It lives in .doriax/user/ instead, which is not committed.
//
// Projects written before that split still carry these keys in project.yaml;
// adoptLegacyProjectState() takes over whatever the workspace does not already define.
class Workspace {
public:
    struct SceneState {
        SceneDisplaySettings displaySettings;
        YAML::Node editorCamera;
        bool hasDisplaySettings = false;
    };

    // .doriax/user, created on demand
    static std::filesystem::path getUserDirectory(const std::filesystem::path& projectPath);

    static bool save(const Project* project);

    // A missing file leaves the workspace empty, which is what a fresh clone starts from
    void load(const std::filesystem::path& projectPath);

    // Fills in only what load() did not find, so the workspace always wins over the
    // stale copy in project.yaml
    void adoptLegacyProjectState(const YAML::Node& projectNode);
    bool hasAdoptedLegacyState() const { return adoptedLegacy; }

    // Entries for scenes the project lists but could not load, encoded as they were
    // read. Without them a checkout missing those files would save the workspace and
    // discard the settings of whoever has them.
    std::map<std::string, YAML::Node> statesForUnresolvedScenes(const Project* project) const;

    bool hasTabs() const { return tabsDefined; }
    const std::vector<TabEntry>& getTabs() const { return tabs; }

    bool hasSelectedScene() const { return selectedSceneDefined; }
    uint32_t getSelectedScene() const { return selectedScene; }

    bool hasTerrainEditorSettings() const { return terrainDefined; }
    const TerrainEditorSettings& getTerrainEditorSettings() const { return terrainEditorSettings; }

    // Keyed by project-relative path, so reordering scenes never rewrites this file
    const SceneState* getSceneState(const std::filesystem::path& sceneFilepath) const;

private:
    static std::filesystem::path getWorkspaceFile(const std::filesystem::path& projectPath);
    static std::string sceneKey(const std::filesystem::path& sceneFilepath);

    void clear();

    std::vector<TabEntry> tabs;
    bool tabsDefined = false;

    uint32_t selectedScene = NULL_PROJECT_SCENE;
    bool selectedSceneDefined = false;

    TerrainEditorSettings terrainEditorSettings;
    bool terrainDefined = false;

    std::map<std::string, SceneState> sceneStates;
    bool adoptedLegacy = false;
};

} // namespace doriax::editor
