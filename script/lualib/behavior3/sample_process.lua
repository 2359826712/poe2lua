return {
  -- 复合节点
  Parallel = require "script.lualib.behavior3.nodes.composites.parallel",
  Selector = require "script.lualib.behavior3.nodes.composites.selector",
  Sequence = require "script.lualib.behavior3.nodes.composites.sequence",

  -- 装饰节点
  Not           = require "script.lualib.behavior3.nodes.decorators.not",
  AlwaysFail    = require "script.lualib.behavior3.nodes.decorators.always_fail",
  AlwaysSuccess = require "script.lualib.behavior3.nodes.decorators.always_success",

  -- 条件节点
  Cmp = require "script.lualib.behavior3.nodes.conditions.cmp",

  -- 行为节点
  Log  = require "script.lualib.behavior3.nodes.actions.log",
  Wait = require "script.lualib.behavior3.nodes.actions.wait",
}