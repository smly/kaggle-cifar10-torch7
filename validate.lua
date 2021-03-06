require 'cutorch'
require 'cunn'
require './SETTINGS'
require './lib/minibatch_sgd'
require './lib/data_augmentation'
require './lib/preprocessing'
require './nin_model.lua'

local function test(model, params, test_x, test_y, classes)
   local confusion = optim.ConfusionMatrix(classes)
   for i = 1, test_x:size(1) do
      local preds = torch.Tensor(10):zero()
      local x = data_augmentation(test_x[i])
      preprocessing(x, params)
      x = x:cuda()
      -- averaging
      for j = 1, x:size(1) do
	 preds = preds + model:forward(x[j]):float()
      end
      preds:div(x:size(1))
      
      confusion:add(preds, test_y[i])
      xlua.progress(i, test_x:size(1))
   end
   xlua.progress(test_x:size(1), test_x:size(1))
   return confusion
end

local function validation()
   local TRAIN_SIZE = 40000
   local TEST_SIZE = 10000
   local MAX_EPOCH = 10

   local x = torch.load(string.format("%s/train_x.bin", DATA_DIR))
   local y = torch.load(string.format("%s/train_y.bin", DATA_DIR))
   local train_x = x:narrow(1, 1, TRAIN_SIZE)
   local train_y = y:narrow(1, 1, TRAIN_SIZE)
   local test_x = x:narrow(1, TRAIN_SIZE + 1, TEST_SIZE)
   local test_y = y:narrow(1, TRAIN_SIZE + 1, TEST_SIZE)
   local model = nin_model():cuda()
   local criterion = nn.MSECriterion():cuda()
   local sgd_config = {
      learningRate = 0.1,
      learningRateDecay = 5.0e-6,
      momentum = 0.9,
      xBatchSize = 12
   }
   local params = nil
   
   print("data augmentation ..")
   train_x, train_y = data_augmentation(train_x, train_y)
   collectgarbage()
   
   print("preprocessing ..")
   params = preprocessing(train_x)
   collectgarbage()
   
   for epoch = 1, MAX_EPOCH do
      if epoch == MAX_EPOCH then
	 -- final epoch
	 sgd_config.learningRateDecay = 0
	 sgd_config.learningRate = 0.001
      end
      model:training()
      print("# " .. epoch)
      print("## train")
      print(minibatch_sgd(model, criterion, train_x, train_y,
			  CLASSES, sgd_config))
      print("## test")
      model:evaluate()
      print(test(model, params, test_x, test_y, CLASSES))
      
      collectgarbage()
   end
end
torch.manualSeed(11)
validation()
