<script setup>
import Checkbox from '../../../Checkbox.vue'

defineProps({config: {type: Object, required: true}})
</script>

<template>
  <fieldset class="mb-4">
    <legend>Sunshine Mod · 本机桌面</legend>
    <Checkbox class="mb-3" id="macos_hide_cursor"
              label="推流期间隐藏本机指针"
              desc="隐藏这台 Mac 上的真实鼠标指针，最后一个连接结束后恢复。与采集画面是否包含指针是独立设置。"
              v-model="config.macos_hide_cursor" default="false" />
    <div class="mb-3">
      <label for="macos_dock_position" class="form-label">推流期间的程序坞位置</label>
      <select id="macos_dock_position" class="form-select" v-model="config.macos_dock_position">
        <option :value="0">保持原位</option>
        <option :value="3">左侧</option>
        <option :value="2">底部</option>
        <option :value="4">右侧</option>
      </select>
      <div class="form-text">最后一个连接结束后恢复原位置。异常退出时，下次启动自动恢复。保存并应用设置后，在下一次推流时生效。</div>
    </div>
  </fieldset>
</template>
