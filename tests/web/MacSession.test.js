import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import { ref } from 'vue'
import AudioVideo from '../../src_assets/common/assets/web/configs/tabs/AudioVideo.vue'
import configTabs from '../../src_assets/common/assets/web/configs/config_tabs.json'

function mountSettings(platform, saved = {}) {
  const config = { ...structuredClone(configTabs.find(tab => tab.id === 'av').options), ...saved }
  const wrapper = mount(AudioVideo, {
    props: { platform, config },
    global: {
      mocks: { $t: key => key },
      provide: { platform: ref(platform), i18n: { t: key => key } },
      stubs: { AdapterNameSelector: true, DisplayOutputSelector: true, DisplayDeviceOptions: true, DisplayModesSettings: true },
    },
  })
  return { wrapper, config }
}

describe('macOS 推流桌面设置', () => {
  it('默认保持本机桌面，保存用户选择的指针与程序坞设置', async () => {
    const { wrapper, config } = mountSettings('macos')
    expect(wrapper.get('#macos_hide_cursor').element.checked).toBe(false)
    expect(config.macos_dock_position).toBe(0)
    await wrapper.get('#macos_hide_cursor').setValue(true)
    expect(config.macos_hide_cursor).toBe('enabled')
    for (const position of [3, 2, 4, 0]) {
      await wrapper.get('#macos_dock_position').setValue(String(position))
      expect(config.macos_dock_position).toBe(position)
    }
    expect(wrapper.text()).toContain('下次启动自动恢复')
    wrapper.unmount()
  })

  it('呈现已经保存的配置', () => {
    const { wrapper } = mountSettings('macos', { macos_hide_cursor: 'enabled', macos_dock_position: '4' })
    expect(wrapper.get('#macos_hide_cursor').element.checked).toBe(true)
    expect(wrapper.get('#macos_dock_position').element.value).toBe('4')
    wrapper.unmount()
  })

  it.each(['windows', 'linux', 'freebsd'])('在 %s 隐藏 macOS 专属设置', platform => {
    const { wrapper } = mountSettings(platform)
    expect(wrapper.find('#macos_hide_cursor').exists()).toBe(false)
    expect(wrapper.find('#macos_dock_position').exists()).toBe(false)
    wrapper.unmount()
  })
})
