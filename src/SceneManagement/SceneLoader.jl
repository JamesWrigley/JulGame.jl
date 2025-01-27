module SceneLoaderModule
    using ..SceneManagement.JulGame
    using ..SceneManagement.SceneBuilderModule

    export loadScene
    function loadScene(projectPath, sceneFileName, isUsingEditor = false)
        SDL2.init()
        if isUsingEditor
            dir = @__DIR__
        else
            dir = pwd()
        end
        main = Scene(projectPath, sceneFileName)
        return main.init(isUsingEditor)
    end
end