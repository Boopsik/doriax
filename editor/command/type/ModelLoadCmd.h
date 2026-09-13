// (c) Eduardo Doria and contributors
// SPDX-License-Identifier: MIT

#pragma once

#include "command/Command.h"
#include "command/type/DeleteEntityCmd.h"
#include "command/type/CreateEntityCmd.h"
#include "Project.h"
#include "math/Vector3.h"
#include "math/Quaternion.h"
#include "subsystem/MeshSystem.h"
#include "yaml-cpp/yaml.h"

#include <atomic>
#include <memory>

namespace doriax::editor{

    class ModelLoadCmd: public Command{

    private:
        YAML::Node oldTransform;
        YAML::Node oldMesh;
        YAML::Node oldModel;
        DeleteEntityCmd* oldSubEntitiesDeleteCmd = nullptr;
        CreateEntityCmd* createEntityCmd = nullptr;

        Project* project;
        uint32_t sceneId;
        Entity entity;

        std::string modelPath;
        bool hasMergeStaticMeshesOverride = false;
        bool mergeStaticMeshesOverride = false;
        bool mergeStaticMeshesChanged = false;

        bool wasModified;
        bool isNewModel = false;
        bool reuseHierarchy = false;
        bool asyncPending = false;
        std::shared_ptr<std::atomic<bool>> cancelFlag;

        // Mesh children the reload keeps, so undo only removes the ones it created
        std::vector<Entity> reusedEntities;

        // A node hierarchy is rebuilt rather than refreshed, so a same-file reload records what the
        // user arranged and puts it back by node name once the new nodes exist.
        struct NodeRef {
            int index = -1;
            std::string name;
        };
        struct LocalPose {
            Vector3 position;
            Quaternion rotation;
            Vector3 scale;
        };
        // An entity the user hung on a model node; parked at the model while the node is rebuilt
        struct ParkedEntity {
            Entity entity = NULL_ENTITY;
            Entity oldParent = NULL_ENTITY;
            NodeRef parent;
            LocalPose pose;
        };
        // An imported part the user moved away from where the file puts it
        struct MovedPart {
            NodeRef part;
            Entity userParent = NULL_ENTITY; // a local group or the model itself
            NodeRef nodeParent;              // when it was dropped on another model node
            LocalPose pose;
        };
        std::vector<ParkedEntity> parkedEntities;
        std::vector<MovedPart> movedParts;

        // The generated mesh entities are destroyed before the load, so their submesh edits are
        // taken aside here. Empty when the asset itself changed.
        MeshSystem::SubmeshOverrides savedSubmeshOverrides;

        static std::vector<Entity> collectModelDeleteRoots(Scene* scene, const ModelComponent& model);
        static bool isMappedMeshNode(const ModelComponent& model, Entity entity);
        static NodeRef makeNodeRef(const ModelComponent& model, int nodeIndex);
        static Entity findModelNode(const ModelComponent& model, const NodeRef& ref);
        static void attachLocal(Scene* scene, Entity child, Entity parent, const LocalPose& pose);

        void recordArrangement(SceneProject* sceneProject, const ModelComponent& model);
        void restoreArrangement(SceneProject* sceneProject, const ModelComponent& model);
        void parkEntities(SceneProject* sceneProject);
        void unparkEntities(SceneProject* sceneProject);

        bool tryLoad();
        void finalizeLoad();
        void schedulePoll();

    public:
        ModelLoadCmd(Project* project, uint32_t sceneId, Entity entity, const std::string& modelPath);
        ModelLoadCmd(Project* project, uint32_t sceneId, Entity entity, const std::string& modelPath, bool mergeStaticMeshes);
        ModelLoadCmd(Project* project, uint32_t sceneId, const std::string& entityName, const Vector3& position, const std::string& modelPath);
        // Terrain object placement: created quiet, under `parent`, with a local transform
        ModelLoadCmd(Project* project, uint32_t sceneId, const std::string& entityName, Entity parent, const Vector3& position, const Quaternion& rotation, const Vector3& scale, const std::string& modelPath);
        ~ModelLoadCmd() override;

        bool execute() override;
        void undo() override;

        bool mergeWith(Command* otherCommand) override;
    };

}
